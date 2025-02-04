module parser;

import std::io;

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

enum UnaryOperator
{
    NONE,
    PLUS,
    MINUS,
}
struct Unary (ParsingExpression)
{
    UnaryOperator operator;
    Primary primary;
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

enum TermOperator
{
    ADD,
    SUB,
}
struct TermRHS
{
    TermOperator operator;
    Factor right;
}
struct Term (ParsingExpression)
{
    Factor left;
    TermRHS[] right;
}
fn String Term.toString(Term* self) @dynamic
{
    String result = "(";
    result = result.tconcat(self.left.toString());
    if (self.right.len > 0) result = result.tconcat(" ");

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

enum FactorOperator
{
    MUL,
    DIV,
}
struct FactorRHS
{
    FactorOperator operator;
    Unary right;
}
struct Factor (ParsingExpression)
{
    Unary left;
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

struct Grouping (ParsingExpression)
{
    ParsingExpression expression;
}
fn String Grouping.toString(Grouping* self) @dynamic
{
    String result = "(";
    result = result.tconcat(self.expression.toString());
    result = result.tconcat(")");
    return result;
}
