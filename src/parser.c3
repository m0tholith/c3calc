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
    fn double evaluate();
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

    if (catch excuse = expr) return ParsingError.INVALID?;

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
    free(self);
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
    return ParsingError.INVALID?;
}
<*
 @require self != null : "primary is null"
 *>
fn void Primary.free(Primary* self) @dynamic
{
    if (self.value.ptr != null) switch (self.value.type)
    {
        case String.typeid:
            free(((String*)self.value).ptr);
            free(self.value.ptr);
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

    result.appendf("%s%s", *self.func, self.primary.toString());

    String str = result.tcopy_str();
    result.free();
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
    return ParsingError.INVALID?;
}
<*
 @require self != null : "function is null"
 *>
fn void Function.free(Function* self) @dynamic
{
    if (self.func != null) free(self.func);
    if (self.primary != null) free(self.primary);
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
	result.append(self.valueList[0].toString());

	for (int i = 1; i < self.valueList.len(); i++)
	{
		result.appendf(" ^ %s", self.valueList[i].toString());
	}

	String str = result.tcopy_str();
	result.free();
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
    result.free();

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
        return ParsingError.INVALID?;
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
    if (self.right.len() == 0)
    {
        return self.left.toString();
    }
    DString result;
    result.new_init();
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
    result.free();

    return str;
}
<*
 @require currentPtr != null : "current is null"
 *>
fn Factor*! parseFactor(TokenList tokens, int* currentPtr)
{
    Factor* factor = mem::new(Factor);
    factor.right.new_init();
    if (try unaryL = parseUnary(tokens, currentPtr))
    {
        factor.left = unaryL;
        int count;
        while (true)
        {
            Token! op = consume(tokens, currentPtr, STAR);
            if (catch excuse = op) op = consume(tokens, currentPtr, SLASH);
            if (catch excuse = op) break;

            factor.right.push(FactorRHS {});
            switch (op.type)
            {
                case STAR:
                    factor.right[count].operator = MUL;
                case SLASH:
                    factor.right[count].operator = DIV;
                default:
                    return ParsingError.INVALID?;
            }
            if (try unary = parseUnary(tokens, currentPtr))
            {
                factor.right[count].right = unary;
                count++;
            }
            else
            {
                return ParsingError.INVALID?;
            }
        }
    }
    return factor;
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
    result.free();

    return str;
}
<*
 @require currentPtr != null : "current is null"
 *>
fn Term*! parseTerm(TokenList tokens, int* currentPtr)
{
    Term* term = mem::new(Term);
    term.right.new_init();
    if (try factorL = parseFactor(tokens, currentPtr))
    {
        term.left = factorL;
        int count;
        while (true)
        {
            Token! op = consume(tokens, currentPtr, PLUS);
            if (catch excuse = op) op = consume(tokens, currentPtr, MINUS);
            if (catch excuse = op) break;

            term.right.push(TermRHS {});
            switch (op.type)
            {
                case PLUS:
                    term.right[count].operator = ADD;
                case MINUS:
                    term.right[count].operator = SUB;
                default:
                    return ParsingError.INVALID?;
            }
            if (try factor = parseFactor(tokens, currentPtr))
            {
                term.right[count].right = factor;
                count++;
            }
            else
            {
                return ParsingError.INVALID?;
            }
        }
        return term;
    }
    free(term);
    return ParsingError.INVALID?;
}
<*
 @require self != null : "term is null"
 *>
fn void Term.free(Term* self) @dynamic
{
    self.left.free();
    foreach (idx, &factorRHS : self.right)
    {
        factorRHS.right.free();
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
    result.append("(");
    result.append(self.expr.toString());
    result.append(")");
    String str = result.tcopy_str();
    result.free();
    return str;
}
<*
 @require currentPtr != null : "current is null"
 *>
fn Grouping*! parseGrouping(TokenList tokens, int* currentPtr)
{
    if (try left_paren = consume(tokens, currentPtr, LEFT_PAREN) && try term = parseTerm(tokens, currentPtr) && try right_paren = consume(tokens, currentPtr, RIGHT_PAREN))
    {
        Grouping* grouping = mem::new(Grouping);
        grouping.expr = term;
        return grouping;
    }
    return ParsingError.INVALID?;
}
<*
 @require self != null : "grouping is null"
 *>
fn void Grouping.free(Grouping* self) @dynamic
{
    self.expr.free();
    mem::free(self);
}
