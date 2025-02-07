module interpreter;

import tokenizer;
import parser;
import std::math;

interface ParsingExpression
{
    fn double evaluate();
}

fn double Expression.evaluate(Expression* self) @dynamic
{
    return self.expr.evaluate();
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
fn double Exponent.evaluate(Exponent* self) @dynamic
{
	if (self.primaryList.len() == 0) return 999.99999;

	double result = self.primaryList[^1].evaluate();
	for (int i = (int)self.primaryList.len() - 1 - 1; i >= 0; i--)
	{
		result = math::pow(self.primaryList[i].evaluate(), result);
	}
	return result;
}
fn double Unary.evaluate(Unary* self) @dynamic
{
    switch (self.operator)
    {
        case NONE:
            return self.exponent.evaluate();
        case MINUS:
            return -1 * self.exponent.evaluate();
    }
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
fn double Grouping.evaluate(Grouping* self) @dynamic
{
    return self.expr.evaluate();
}
