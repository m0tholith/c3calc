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
fn Token! previous(TokenList tokens, int* current)
{
    if ((*current) == 0 || (*current) > tokens.len())
    {
        return TokenWalk.OOB?;
    }
    return tokens[(usz)(*current - 1)];
}
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
    Term* term;
}
fn Expression*! parseExpression(TokenList tokens)
{
    Expression* result = malloc(Expression.sizeof);

    int* current = mem::new(int);
    Term*! term = parseTerm(tokens, current);
    free(current);

    if (catch excuse = term) return ParsingError.INVALID?;

    result.term = term;
    return result;
}
fn String Expression.toString(Expression* self) @dynamic
{
    return self.term.toString();
}
fn double Expression.evaluate(Expression* self) @dynamic
{
    return self.term.evaluate();
}
fn void Expression.free(Expression* self) @dynamic
{
    if (self == null) return;
    self.term.free();
    free(self);
}

struct Primary (ParsingExpression)
{
    // two options:
    //  - String* number
    //  - Grouping* grouping
    any value;
}
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
fn Primary*! parsePrimary(TokenList tokens, int* currentPtr)
{
    Primary* primary = mem::new(Primary);
    if (try number = consume(tokens, currentPtr, TokenType.NUMBER))
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
fn double Primary.evaluate(Primary* self) @dynamic
{
    switch (self.value.type)
    {
        case String.typeid:
            return (*(String*)self.value).to_double()!!;
        case Grouping.typeid:
            return ((Grouping*)self.value).evaluate();
    }
    return 999.99999;
}
fn void Primary.free(Primary* self) @dynamic
{
    if (self == null) return;
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

enum UnaryOperator : int
{
    NONE,
    MINUS,
}
struct Unary (ParsingExpression)
{
    UnaryOperator operator;
    Primary* primary;
}
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
    result.append(self.primary.toString());
    String str = result.tcopy_str();
    result.free();

    return str;
}
fn Unary*! parseUnary(TokenList tokens, int* currentPtr)
{
    Unary* unary = mem::new(Unary);
    if (try op = consume(tokens, currentPtr, TokenType.MINUS))
    {
        unary.operator = UnaryOperator.MINUS;
    }
    Primary*! p = parsePrimary(tokens, currentPtr);
    if (catch excuse = p)
    {
        return ParsingError.INVALID?;
    }
    unary.primary = p;
    return unary;
}
fn double Unary.evaluate(Unary* self) @dynamic
{
    switch (self.operator)
    {
        case NONE:
            return self.primary.evaluate();
        case MINUS:
            return -1 * self.primary.evaluate();
    }
}
fn void Unary.free(Unary* self) @dynamic
{
    if (self == null) return;
    self.primary.free();
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
            Token! op = consume(tokens, currentPtr, TokenType.STAR);
            if (catch excuse = op) op = consume(tokens, currentPtr, TokenType.SLASH);
            if (catch excuse = op) break;

            factor.right.push(FactorRHS {});
            switch (op.type)
            {
                case STAR:
                    factor.right[count].operator = FactorOperator.MUL;
                case SLASH:
                    factor.right[count].operator = FactorOperator.DIV;
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
fn double Factor.evaluate(Factor* self) @dynamic
{
    double result = self.left.evaluate();
    double unaryEval;
    foreach (idx, unaryRHS : self.right)
    {
        unaryEval = unaryRHS.right.evaluate();
        switch (unaryRHS.operator)
        {
            case MUL:
                result *= unaryEval;
            case DIV:
                result /= unaryEval;
        }
    }
    return result;
}
fn void Factor.free(Factor* self) @dynamic
{
    if (self == null) return;
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
            Token! op = consume(tokens, currentPtr, TokenType.PLUS);
            if (catch excuse = op) op = consume(tokens, currentPtr, TokenType.MINUS);
            if (catch excuse = op) break;

            term.right.push(TermRHS {});
            switch (op.type)
            {
                case PLUS:
                    term.right[count].operator = TermOperator.ADD;
                case MINUS:
                    term.right[count].operator = TermOperator.SUB;
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
fn double Term.evaluate(Term* self) @dynamic
{
    double result = self.left.evaluate();
    double factorEval;
    foreach (idx, factorRHS : self.right)
    {
        switch (factorRHS.operator)
        {
            case ADD:
                factorEval = +1;
            case SUB:
                factorEval = -1;
        }
        factorEval *= factorRHS.right.evaluate();
        result += factorEval;
    }
    return result;
}
fn void Term.free(Term* self) @dynamic
{
    if (self == null) return;
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
    Term* term;
}
fn String Grouping.toString(Grouping* self) @dynamic
{
    DString result;
    result.new_init();
    result.append("(");
    result.append(self.term.toString());
    result.append(")");
    String str = result.tcopy_str();
    result.free();
    return str;
}
fn Grouping*! parseGrouping(TokenList tokens, int* currentPtr)
{
    if (try left_paren = consume(tokens, currentPtr, LEFT_PAREN) && try term = parseTerm(tokens, currentPtr) && try right_paren = consume(tokens, currentPtr, RIGHT_PAREN))
    {
        Grouping* grouping = mem::new(Grouping);
        grouping.term = term;
        return grouping;
    }
    return ParsingError.INVALID?;
}
fn double Grouping.evaluate(Grouping* self) @dynamic
{
    return self.term.evaluate();
}
fn void Grouping.free(Grouping* self) @dynamic
{
    if (self == null) return;
    self.term.free();
    mem::free(self);
}
