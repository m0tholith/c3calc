module interpreter;

import tokenizer;
import parser;
import std::math;

interface ParsingExpression
{
    fn double evaluate();
}

<*
 @require self != null : "expression is null"
 *>
fn double Expression.evaluate(Expression* self) @dynamic
{
    return self.expr.evaluate();
}
<*
 @require self != null : "primary is null"
 *>
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
<*
 @require self != null : "function is null"
 *>
fn double Function.evaluate(Function* self) @dynamic
{
    // @todo: evaluate actual function
    return self.primary.evaluate();
}
<*
 @require self != null : "exponent is null"
 *>
fn double Exponent.evaluate(Exponent* self) @dynamic
{
	if (self.valueList.len() == 0) return 999.99999;

	double result = self.valueList[^1].evaluate();
	for (int i = (int)self.valueList.len() - 1 - 1; i >= 0; i--)
	{
		result = math::pow(self.valueList[i].evaluate(), result);
	}
	return result;
}
<*
 @require self != null : "unary is null"
 *>
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
<*
 @require self != null : "factor is null"
 *>
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
<*
 @require self != null : "term is null"
 *>
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
<*
 @require self != null : "grouping is null"
 *>
fn double Grouping.evaluate(Grouping* self) @dynamic
{
    return self.expr.evaluate();
}
