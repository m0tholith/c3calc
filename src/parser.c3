module parser;

import tokenizer;
import std::io;
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
fn bool Token.checkType(Token* token, TokenType type)
{
    if (token.type.ordinal & type.ordinal > 0)
    {
        return true;
    }
    return false;
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
    if ((*current) < 0 || (*current) >= tokens.len() - 1)
    {
        return TokenWalk.OOB?;
    }
    return tokens[*current];
}

interface ParsingExpression
{
    fn String toString();
}

struct Primary (ParsingExpression)
{
    any number; // either string pointer (String*) containing number, or Grouping pointer
}
fn String Primary.toString(Primary* self) @dynamic
{
    switch (self.number.type)
    {
        case String.typeid:
            return *(String*)self.number;
        case Grouping.typeid:
            return ((Grouping*)self.number).toString();
        default:
            io::printfn("Tried to convert primary to string, but type (%i) invalid", self.number.type);
            return "";
    }
}
fn Primary*! parsePrimary(TokenList tokens, int* currentPtr)
{
    if (try number = consume(tokens, currentPtr, TokenType.NUMBER))
    {
        io::printfn("%s", number.content);
        Primary* primary = malloc(Primary.sizeof);
        primary.number = &number.content;
        return primary;
    }
    else
    {
        io::printn("primary is group");
        Primary* primary = malloc(Primary.sizeof);
        Grouping*! grouping = parseGrouping(tokens, currentPtr);
        if (catch excuse = grouping)
        {
            return ParsingError.INVALID?;
        }
        primary.number = grouping;
        return primary;
    }
}

enum UnaryOperator
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
    String result = "(";
    result = result.tconcat(self.primary.toString());
    switch (self.operator)
    {
        case PLUS:
            result = result.tconcat(" +");
        case MINUS:
            result = result.tconcat(" -");

        case NONE:
        default:
            break;
    }
    result = result.tconcat(")");

    return result;
}
fn Unary*! parseUnary(TokenList tokens, int* currentPtr)
{
    Unary* unary = malloc(Unary.sizeof);
    if (try op = consume(tokens, currentPtr, TokenType.from_ordinal(TokenType.PLUS.ordinal | TokenType.MINUS.ordinal)))
    {
        switch (op.type)
        {
            case PLUS:
                unary.operator = UnaryOperator.PLUS;
            case MINUS:
                unary.operator = UnaryOperator.MINUS;
            default:
                return ParsingError.INVALID?;
        }
    }
    else if (try number = consume(tokens, currentPtr, TokenType.NUMBER))
    {
        unary.operator = UnaryOperator.NONE;
    }
    else
    {
        return ParsingError.INVALID?;
    }
    io::printfn("%d", unary.operator);
    Primary*! primary = parsePrimary(tokens, currentPtr);
    if (catch excuse = primary)
    {
        return ParsingError.INVALID?;
    }
    unary.primary = primary;
    return unary;
}

enum TermOperator
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
    String result = "(";
    result = result.tconcat(self.left.toString());
    if (self.right.len() > 0) result = result.tconcat(" ");

    foreach (idx, rhs : self.right)
    {
        result = result.tconcat(rhs.right.toString());
        switch (rhs.operator)
        {
            case ADD:
                result = result.tconcat(" +");
            case SUB:
                result = result.tconcat(" -");
        }
    }
    result = result.tconcat(")");

    return result;
}
fn Term*! parseTerm(TokenList tokens, int* currentPtr)
{
    Term* term = malloc(Term.sizeof);
    term.right.new_init();
    if (try factorL = parseFactor(tokens, currentPtr))
    {
        term.left = factorL;
        int count;
        while (try op = consume(tokens, currentPtr, TokenType.from_ordinal(TokenType.PLUS.ordinal | TokenType.MINUS.ordinal)))
        {
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
            Factor*! factor = parseFactor(tokens, currentPtr);
            if (catch excuse = factor)
            {
                return ParsingError.INVALID?;
            }
            term.right[count].right = factor;
            count++;
        }
    }
    return term;
}

enum FactorOperator
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
    FactorRHS[] right;
}
fn String Factor.toString(Factor* self) @dynamic
{
    String result = "(";
    result = result.tconcat(self.left.toString());
    if (self.right.len > 0) result = result.tconcat(" ");

    foreach (idx, rhs : self.right)
    {
        result = result.tconcat(rhs.right.toString());
        switch (rhs.operator)
        {
            case MUL:
                result = result.tconcat(" *");
            case DIV:
                result = result.tconcat(" /");
        }
    }
    result = result.tconcat(")");

    return result;
}
fn Factor*! parseFactor(TokenList tokens, int* currentPtr)
{
    Factor* factor = malloc(Factor.sizeof);
    if (try unaryL = parseUnary(tokens, currentPtr))
    {
        factor.left = unaryL;
        int count;
        while (try op = consume(tokens, currentPtr, TokenType.from_ordinal(TokenType.STAR.ordinal | TokenType.SLASH.ordinal)))
        {
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

struct Grouping (ParsingExpression)
{
    Term* term;
}
fn String Grouping.toString(Grouping* self) @dynamic
{
    String result = "(";
    result = result.tconcat(self.term.toString());
    result = result.tconcat(")");
    return result;
}
fn Grouping*! parseGrouping(TokenList tokens, int* currentPtr)
{
    if (try left_paren = consume(tokens, currentPtr, TokenType.LEFT_PAREN))
    {
        if (try term = parseTerm(tokens, currentPtr) && try right_paren = consume(tokens, currentPtr, RIGHT_PAREN))
        {
            Grouping* grouping = malloc(Grouping.sizeof);
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
