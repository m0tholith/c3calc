module parser;

import tokenizer;
import std::io;
import std::math;
import std::core::mem;
import std::collections;

// helper functions for parsing
fault TokenWalk
{
    NOTFOUND,
    OOB,
}
fault ParsingError
{
    INVALID,
    PRIMARY_FAIL,
    FUNCTION_FAIL,
    EXPONENT_FAIL,
    UNARY_FAIL,
    FACTOR_FAIL,
    TERM_FAIL,
    GROUPING_FAIL,
}
<*
 @require current != null : "current ptr is null"
 *>
fn Token! consume(TokenList tokens, int* current, TokenType type)
{
    if ((*current) >= tokens.len())
    {
        return TokenWalk.OOB?;
    }
    if (tokens[(*current)].checkType(type))
    {
        return tokens[(*current)++];
    }
    return TokenWalk.NOTFOUND?;
}
<*
 @require current != null : "current ptr is null"
 *>
fn Token! previous(TokenList tokens, int* current)
{
    if ((*current) == 0 || (*current) > tokens.len())
    {
        return TokenWalk.OOB?;
    }
    return tokens[(usz)(*current - 1)];
}
<*
 @require current != null : "current ptr is null"
 *>
fn Token! peek(TokenList tokens, int* current)
{
    if ((*current) < 0 || (*current) >= tokens.len())
    {
        return TokenWalk.OOB?;
    }
    return tokens[*current];
}

interface ParsingExpression
{
    fn String toString();
    fn void free();
}


struct Expression (ParsingExpression)
{
    Term* expr;
}
fn Expression*! parseExpression(TokenList tokens)
{
    Expression* result = malloc(Expression.sizeof);

    int* current = mem::new(int);
    Term*! expr = parseTerm(tokens, current);
    free(current);

    if (catch excuse = expr) return excuse?;

    result.expr = expr;
    return result;
}
<*
 @require self != null : "expression is null"
 *>
fn String Expression.toString(Expression* self) @dynamic
{
    return self.expr.toString();
}
<*
 @require self != null : "expression is null"
 *>
fn void Expression.free(Expression* self) @dynamic
{
    self.expr.free();
    mem::free(self);
}

struct Primary (ParsingExpression)
{
    // two options:
    //  - String* number
    //  - Grouping* grouping
    any value;
}
<*
 @require self != null : "primary is null"
 *>
fn String Primary.toString(Primary* self) @dynamic
{
    switch (self.value.type)
    {
        case String.typeid:
            return *(String*)self.value;
        case Grouping.typeid:
            return ((Grouping*)self.value).toString();
        default:
            io::eprintf("Could not convert primary to string: invalid value type");
    }
    return "(ERROR!)";
}
<*
 @require currentPtr != null : "current is null"
 *>
fn Primary*! parsePrimary(TokenList tokens, int* currentPtr)
{
    Primary* primary = mem::new(Primary);
    if (try number = consume(tokens, currentPtr, NUMBER))
    {
        primary.value = @clone(number.content.copy());
        return primary;
    }
    else if (try grouping = parseGrouping(tokens, currentPtr))
    {
        primary.value = grouping;
        return primary;
    }
    mem::free(primary);
    return ParsingError.PRIMARY_FAIL?;
}
<*
 @require self != null : "primary is null"
 *>
fn void Primary.free(Primary* self) @dynamic
{
    if (self.value.ptr != null) switch (self.value.type)
    {
        case String.typeid:
            free(*(String*)self.value);
            free(self.value);
        case Grouping.typeid:
            ((Grouping*)self.value).free();
    }
    mem::free(self);
}

struct Function (ParsingExpression)
{
    String* func;
    Primary* primary;
}
<*
 @require self != null : "function is null"
 *>
fn String Function.toString(Function* self) @dynamic
{
    DString result;
    result.new_init();
    defer result.free();

    result.appendf("%s%s", *self.func, self.primary.toString());

    String str = result.tcopy_str();
    return str;
}
<*
 @require currentPtr != null : "current is null"
 *>
fn Function*! parseFunction(TokenList tokens, int* currentPtr)
{
    Function* function = mem::new(Function);
    if (try word = consume(tokens, currentPtr, WORD))
    {
        function.func = @clone(word.content);
    }
    else
    {
        function.func = mem::new(String, "");
    }
    if (try primary = parsePrimary(tokens, currentPtr))
    {
        function.primary = primary;
        return function;
    }
    function.free();
    return ParsingError.FUNCTION_FAIL?;
}
<*
 @require self != null : "function is null"
 *>
fn void Function.free(Function* self) @dynamic
{
    if (self.func != null) free(self.func);
    if (self.primary != null) self.primary.free();
    mem::free(self);
}

struct Exponent (ParsingExpression)
{
	List(<Function*>) valueList;
}
<*
 @require self != null : "exponent is null"
 *>
fn String Exponent.toString(Exponent* self) @dynamic
{
	if (self.valueList.len() == 1) return self.valueList[0].toString();

	DString result;
	result.new_init();
	defer result.free();
	result.append(self.valueList[0].toString());

	for (int i = 1; i < self.valueList.len(); i++)
	{
		result.appendf(" ^ %s", self.valueList[i].toString());
	}

	String str = result.tcopy_str();
	return str;
}
<*
 @require currentPtr != null : "current is null"
 *>
fn Exponent*! parseExponent(TokenList tokens, int* currentPtr)
{
	Exponent* exponent = mem::new(Exponent);
	exponent.valueList.new_init();
	while (try function = parseFunction(tokens, currentPtr))
	{
		exponent.valueList.push(function);
		if (catch nonExponent = consume(tokens, currentPtr, CARET))
		{
			break;
		}
	}
    if (exponent.valueList.len() == 0)
    {
        return ParsingError.EXPONENT_FAIL?;
    }
	return exponent;
}
<*
 @require self != null : "exponent is null"
 *>
fn void Exponent.free(Exponent* self) @dynamic
{
	foreach (primary : self.valueList)
	{
		primary.free();
	}
	self.valueList.free();
	mem::free(self);
}

enum UnaryOperator : int
{
    NONE,
    MINUS,
}
struct Unary (ParsingExpression)
{
    UnaryOperator operator;
    Exponent* exponent;
}
<*
 @require self != null : "unary is null"
 *>
fn String Unary.toString(Unary* self) @dynamic
{
    DString result;
    result.new_init();
    defer result.free();
    switch (self.operator)
    {
        case MINUS:
            result.append("-");

        case NONE:
        default:
            break;
    }
    result.append(self.exponent.toString());
    String str = result.tcopy_str();

    return str;
}
<*
 @require currentPtr != null : "current is null"
 *>
fn Unary*! parseUnary(TokenList tokens, int* currentPtr)
{
    Unary* unary = mem::new(Unary);
    if (try op = consume(tokens, currentPtr, MINUS))
    {
        unary.operator = UnaryOperator.MINUS;
    }
    Exponent*! p = parseExponent(tokens, currentPtr);
    if (catch excuse = p)
    {
        mem::free(unary);
        return excuse?;
    }
    unary.exponent = p;
    return unary;
}
<*
 @require self != null : "unary is null"
 *>
fn void Unary.free(Unary* self) @dynamic
{
    self.exponent.free();
    mem::free(self);
}

enum FactorOperator : int
{
    MUL,
    DIV,
}
struct FactorRHS
{
    FactorOperator operator;
    Unary* right;
}
struct Factor (ParsingExpression)
{
    Unary* left;
    List(<FactorRHS>) right;
}
<*
 @require self != null : "factor is null"
 *>
fn String Factor.toString(Factor* self) @dynamic
{
    DString result;
    result.new_init();
    defer result.free();
    result.append(self.left.toString());

    foreach (idx, rhs : self.right)
    {
        switch (rhs.operator)
        {
            case MUL:
                result.append(" * ");
            case DIV:
                result.append(" / ");
        }
        result.append(rhs.right.toString());
    }
    String str = result.tcopy_str();

    return str;
}
<*
 @require currentPtr != null : "current is null"
 *>
fn Factor*! parseFactor(TokenList tokens, int* currentPtr)
{
    Factor* factor = mem::new(Factor);
    if (try unaryL = parseUnary(tokens, currentPtr))
    {
        factor.right.new_init();
        factor.left = unaryL;
        int count;
        while (true)
        {
            Token! op = consume(tokens, currentPtr, STAR);
            if (catch excuse = op) op = consume(tokens, currentPtr, SLASH);
            if (catch excuse = op) break;

            FactorRHS rhs = {};
            switch (op.type)
            {
                case STAR:
                    rhs.operator = MUL;
                case SLASH:
                    rhs.operator = DIV;
                default:
                    factor.free();
                    return ParsingError.FACTOR_FAIL?;
            }
            Unary*! unary = parseUnary(tokens, currentPtr);
            if (catch excuse = unary)
            {
                factor.free();
                return excuse?;
            }
            rhs.right = unary;
            factor.right.push(rhs);
        }
        return factor;
    }
    mem::free(factor);
    return ParsingError.FACTOR_FAIL?;
}
<*
 @require self != null : "factor is null"
 *>
fn void Factor.free(Factor* self) @dynamic
{
    self.left.free();
    foreach (idx, &unaryRHS : self.right)
    {
        unaryRHS.right.free();
    }
    self.right.free();
    mem::free(self);
}

enum TermOperator : int
{
    ADD,
    SUB,
}
struct TermRHS
{
    TermOperator operator;
    Factor* right;
}
struct Term (ParsingExpression)
{
    Factor* left;
    List(<TermRHS>) right;
}
<*
 @require self != null : "term is null"
 *>
fn String Term.toString(Term* self) @dynamic
{
    if (self.right.len() == 0)
    {
        return self.left.toString();
    }
    DString result;
    result.new_init();
    defer result.free();
    result.append(self.left.toString());

    foreach (idx, rhs : self.right)
    {
        switch (rhs.operator)
        {
            case ADD:
                result.append(" + ");
            case SUB:
                result.append(" - ");
        }
        result.append(rhs.right.toString());
    }
    String str = result.tcopy_str();

    return str;
}
<*
 @require currentPtr != null : "current is null"
 *>
fn Term*! parseTerm(TokenList tokens, int* currentPtr)
{
    Term* term = mem::new(Term);
    if (try factorL = parseFactor(tokens, currentPtr))
    {
        term.right.new_init();
        term.left = factorL;
        int count;
        while (true)
        {
            Token! op = consume(tokens, currentPtr, PLUS);
            if (catch excuse = op) op = consume(tokens, currentPtr, MINUS);
            if (catch excuse = op) break;

            TermRHS rhs = {};
            switch (op.type)
            {
                case PLUS:
                    rhs.operator = ADD;
                case MINUS:
                    rhs.operator = SUB;
                default:
                    term.free();
                    return ParsingError.TERM_FAIL?;
            }
            Factor*! factor = parseFactor(tokens, currentPtr);
            if (catch excuse = factor)
            {
                term.free();
                return excuse?;
            }
            rhs.right = factor;
            term.right.push(rhs);
        }
        return term;
    }
    mem::free(term);
    return ParsingError.TERM_FAIL?;
}
<*
 @require self != null : "term is null"
 *>
fn void Term.free(Term* self) @dynamic
{
    self.left.free();
    foreach (idx, &termRHS : self.right)
    {
        termRHS.right.free();
    }
    self.right.free();
    mem::free(self);
}

struct Grouping (ParsingExpression)
{
    Term* expr;
}
<*
 @require self != null : "grouping is null"
 *>
fn String Grouping.toString(Grouping* self) @dynamic
{
    DString result;
    result.new_init();
    defer result.free();

    result.append("(");
    result.append(self.expr.toString());
    result.append(")");

    String str = result.tcopy_str();

    return str;
}
<*
 @require currentPtr != null : "current is null"
 *>
fn Grouping*! parseGrouping(TokenList tokens, int* currentPtr)
{
    Token! leftParen = consume(tokens, currentPtr, LEFT_PAREN);
    if (catch excuse = leftParen) return ParsingError.GROUPING_FAIL?;

    Term*! term = parseTerm(tokens, currentPtr);
    if (catch excuse = term) return excuse?;

    Token! rightParen = consume(tokens, currentPtr, RIGHT_PAREN);
    if (catch excuse = rightParen)
    {
        term.free();
        return ParsingError.GROUPING_FAIL?;
    }
    
    Grouping* grouping = mem::new(Grouping);
    grouping.expr = term;
    return grouping;
}
<*
 @require self != null : "grouping is null"
 *>
fn void Grouping.free(Grouping* self) @dynamic
{
    self.expr.free();
    mem::free(self);
}
