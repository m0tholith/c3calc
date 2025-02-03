module parser;

import std::io;

interface Expression
{
    fn String toString();
}

struct Literal (Expression)
{
    String value;
}
fn String Literal.toString(Literal* self) @dynamic
{
    return self.value;
}

struct Binary (Expression)
{
    Expression left;
    String operator;
    Expression right;
}
fn String Binary.toString(Binary* self) @dynamic
{
    return
        "(".tconcat(
        self.left.toString().tconcat(
        " ".tconcat(
        self.right.toString().tconcat(
        " ".tconcat(
        self.operator.tconcat(
        ")"
        ))))))
        ;
}
