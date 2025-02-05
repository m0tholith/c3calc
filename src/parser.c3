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
fn double strToNum(String str)
{
    double result = 0;
    int power = 0;
    foreach_r (digit : str)
    {
        if (digit == '.') continue;
        double digitInt = (double)digit - (double)'0';
        result += digitInt * (double)math::pow(10, power);

        power++;
    }
    if (try idx = str.index_of_char('.'))
    {
        result /= (double)math::pow(10, (int)(str.len - idx - 1));
    }
    return result;
}

interface ParsingExpression
{
    fn String toString();
    fn double evaluate();
}


struct Expression (ParsingExpression)
{
    Term* term;
}
fn Expression*! parseExpression(TokenList tokens)
{
    Expression* result = malloc(Expression.sizeof);

    int* current = malloc(int.sizeof);
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

struct Primary (ParsingExpression)
{
    String number;
}
fn String Primary.toString(Primary* self) @dynamic
{
    return self.number;
}
fn Primary*! parsePrimary(TokenList tokens, int* currentPtr)
{
    if (try number = consume(tokens, currentPtr, TokenType.NUMBER))
    {
        Primary* primary = mem::new(Primary);
        primary.number = number.content;
        return primary;
    }
    return ParsingError.INVALID?;
}
fn double Primary.evaluate(Primary* self) @dynamic
{
    return strToNum(self.number);
}

enum UnaryOperator : int
{
    NONE,
    PLUS,
    MINUS,
}
struct Unary (ParsingExpression)
{
    UnaryOperator operator;
    Primary* primary;
}
fn String Unary.toString(Unary* self) @dynamic
{
    String result = "";
    switch (self.operator)
    {
        case PLUS:
            result = result.concat("+");
        case MINUS:
            result = result.concat("-");

        case NONE:
        default:
            break;
    }
    result = result.concat(self.primary.toString());

    return result;
}
fn Unary*! parseUnary(TokenList tokens, int* currentPtr)
{
    Unary* unary = mem::new(Unary);
    if (try op = consume(tokens, currentPtr, TokenType.PLUS))
    {
        unary.operator = UnaryOperator.PLUS;
    }
    else if (try op = consume(tokens, currentPtr, TokenType.MINUS))
    {
        unary.operator = UnaryOperator.MINUS;
    }
    else if (try token = peek(tokens, currentPtr) && token.type == TokenType.NUMBER)
    {
        unary.operator = UnaryOperator.NONE;
    }
    else
    {
        return ParsingError.INVALID?;
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
        case PLUS:
            return self.primary.evaluate();
        case MINUS:
            return -1 * self.primary.evaluate();
    }
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
    String result;
    result = result.concat(self.left.toString());

    foreach (idx, rhs : self.right)
    {
        switch (rhs.operator)
        {
            case ADD:
                result = result.concat(" + ");
            case SUB:
                result = result.concat(" - ");
        }
        result = result.concat(rhs.right.toString());
    }

    return result;
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
    }
    return term;
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
    String result;
    result = result.concat(self.left.toString());

    foreach (idx, rhs : self.right)
    {
        switch (rhs.operator)
        {
            case MUL:
                result = result.concat(" * ");
            case DIV:
                result = result.concat(" / ");
        }
        result = result.concat(rhs.right.toString());
    }

    return result;
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

struct Grouping (ParsingExpression)
{
    Term* term;
}
fn String Grouping.toString(Grouping* self) @dynamic
{
    String result = "(";
    result = result.concat(self.term.toString());
    result = result.concat(")");
    return result;
}
fn Grouping*! parseGrouping(TokenList tokens, int* currentPtr)
{
    if (try left_paren = consume(tokens, currentPtr, TokenType.LEFT_PAREN))
    {
        if (try term = parseTerm(tokens, currentPtr) && try right_paren = consume(tokens, currentPtr, RIGHT_PAREN))
        {
            Grouping* grouping = mem::new(Grouping);
            grouping.term = term;
            return grouping;
        }
        else
        {
            return ParsingError.INVALID?;
        }
    }
    else
    {
        return ParsingError.INVALID?;
    }
}
fn double Grouping.evaluate(Grouping* self) @dynamic
{
    return self.term.evaluate();
}
