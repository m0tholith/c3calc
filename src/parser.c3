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
    if (token.type == type)
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
    if ((*current) < 0 || (*current) >= tokens.len())
    {
        return TokenWalk.OOB?;
    }
    return tokens[*current];
}

interface ParsingExpression
{
    fn String toString();
}

enum PrimaryType
{
    NUMBER,
    GROUPING,
}
struct Primary (ParsingExpression)
{
    PrimaryType type;
    String number;      // used if type is NUMBER
    Grouping *grouping; // used if type is GROUPING
}
fn String Primary.toString(Primary* self) @dynamic
{
    return self.number;
}
fn Primary*! parsePrimary(TokenList tokens, int* currentPtr)
{
    if (try number = consume(tokens, currentPtr, TokenType.NUMBER))
    {
        io::printfn("primary number %s", number.content);
        Primary* primary = mem::new(Primary);
        primary.type = NUMBER;
        primary.number = number.content;
        return primary;
    }
    else if (try parenToken = peek(tokens, currentPtr) && parenToken.checkType(TokenType.LEFT_PAREN))
    {
        io::printn("primary is group");
        Primary* primary = mem::new(Primary);
        primary.type = GROUPING;
        Grouping*! grouping = parseGrouping(tokens, currentPtr);
        if (catch excuse = grouping)
        {
            return ParsingError.INVALID?;
        }
        primary.grouping = grouping;
        return primary;
    }
    return ParsingError.INVALID?;
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
    String result = "(";
    result = result.concat(self.primary.toString());
    switch (self.operator)
    {
        case PLUS:
            result = result.concat(" +");
        case MINUS:
            result = result.concat(" -");

        case NONE:
        default:
            break;
    }
    result = result.concat(")");

    return result;
}
fn Unary*! parseUnary(TokenList tokens, int* currentPtr)
{
    Unary* unary = mem::new(Unary);
    if (try op = consume(tokens, currentPtr, TokenType.PLUS))
    {
        io::printn("unary plus");
        unary.operator = UnaryOperator.PLUS;
    }
    else if (try op = consume(tokens, currentPtr, TokenType.MINUS))
    {
        io::printn("unary minus");
        unary.operator = UnaryOperator.MINUS;
    }
    else if (try token = peek(tokens, currentPtr) && token.type == TokenType.NUMBER)
    {
        io::printn("unary op none");
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
    io::printfn("unary primary '%s' (%s)", unary.primary.toString(), unary.toString());
    return unary;
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
    String result = "(";
    result = result.concat(self.left.toString());
    if (self.right.len() > 0) result = result.concat(" ");

    foreach (idx, rhs : self.right)
    {
        result = result.concat(rhs.right.toString());
        switch (rhs.operator)
        {
            case ADD:
                result = result.concat(" +");
            case SUB:
                result = result.concat(" -");
        }
    }
    result = result.concat(")");

    return result;
}
fn Term*! parseTerm(TokenList tokens, int* currentPtr)
{
    Term* term = mem::new(Term);
    term.right.new_init();
    if (try factorL = parseFactor(tokens, currentPtr))
    {
        io::printn("term has factor");
        term.left = factorL;
        int count;
        while (true)
        {
            Token! op = consume(tokens, currentPtr, TokenType.PLUS);
            if (catch excuse = op) op = consume(tokens, currentPtr, TokenType.MINUS);
            if (catch excuse = op) break;

            io::printfn("term op %d", op.type);

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
                io::printn("term has factor");
                term.right[count].right = factor;
                count++;
            }
            else
            {
                io::printn("term DOES NOT HAVE factor");
                return ParsingError.INVALID?;
            }
        }
    }
    return term;
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
    String result = "(";
    result = result.concat(self.left.toString());
    if (self.right.len() > 0) result = result.concat(" ");

    foreach (idx, rhs : self.right)
    {
        result = result.concat(rhs.right.toString());
        switch (rhs.operator)
        {
            case MUL:
                result = result.concat(" *");
            case DIV:
                result = result.concat(" /");
        }
    }
    result = result.concat(")");

    return result;
}
fn Factor*! parseFactor(TokenList tokens, int* currentPtr)
{
    Factor* factor = mem::new(Factor);
    factor.right.new_init();
    if (try unaryL = parseUnary(tokens, currentPtr))
    {
        io::printn("factor has unary");
        factor.left = unaryL;
        int count;
        while (true)
        {
            Token! op = consume(tokens, currentPtr, TokenType.STAR);
            if (catch excuse = op) op = consume(tokens, currentPtr, TokenType.SLASH);
            if (catch excuse = op) break;

            io::printfn("factor op %d", op.type);

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
                io::printn("factor has unary");
                factor.right[count].right = unary;
                count++;
            }
            else
            {
                io::printn("factor DOES NOT HAVE unary");
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
