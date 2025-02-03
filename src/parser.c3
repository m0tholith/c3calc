module parser;

import std::io;

interface Expression
{
    fn String print();
}

struct Literal (Expression)
{
    String value;
}
fn String Literal.print(Literal* self) @dynamic
{
    return self.value;
}

struct Binary (Expression)
{
    Expression left;
    String operator;
    Expression right;
}
fn String Binary.print(Binary* self) @dynamic
{
    return
        "(".tconcat(
        self.left.print().tconcat(
        " ".tconcat(
        self.right.print().tconcat(
        " ".tconcat(
        self.operator.tconcat(
        ")"
        ))))))
        ;
}
