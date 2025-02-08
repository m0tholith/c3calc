module c3calc;

import tokenizer;
import parser;
import interpreter;
import std::io;
import std::math;

fn int main(String[] args)
{
    Interpreter interpreter;
    interpreter.new_init();
	defer interpreter.free();

    interpreter.add_function("sin", &sin);
    interpreter.add_function("cos", &cos);
    interpreter.add_function("tan", &tan);
    interpreter.add_function("cotan", &cotan);
    interpreter.add_function("sec", &sec);
    interpreter.add_function("cosec", &cosec);
    interpreter.add_function("sinh", &sinh);
    interpreter.add_function("cosh", &cosh);
    interpreter.add_function("tanh", &atan);
    interpreter.add_function("cotanh", &cotanh);
    interpreter.add_function("sech", &sec);
    interpreter.add_function("cosech", &cosech);

    interpreter.add_function("asin", &asin);
    interpreter.add_function("acos", &acos);
    interpreter.add_function("atan", &atan);
    interpreter.add_function("asinh", &asinh);
    interpreter.add_function("acosh", &acosh);
    interpreter.add_function("atanh", &atanh);

    interpreter.add_function("floor", &floor);
    interpreter.add_function("ceil", &ceil);
    interpreter.add_function("round", &round);

    interpreter.add_function("ln", &ln);
    interpreter.add_function("log10", &log10);
    interpreter.add_function("log2", &log2);

    interpreter.add_function("sqrt", &sqrt);
    interpreter.add_function("cbrt", &cbrt);

	double! result = interpreter.evaluate(args[1]);
    if (catch excuse = result)
    {
        io::eprintfn("ERROR: %s", excuse);
		return -1;
    }
	io::printfn("%s = %f", interpreter.format(args[1])!!, result);
	return 0;
}

fn double sin   (double x) { return math::sin(x); }
fn double cos   (double x) { return math::cos(x); }
fn double tan   (double x) { return math::tan(x); }
fn double cotan (double x) { return math::cotan(x); }
fn double sec   (double x) { return math::sec(x); }
fn double cosec (double x) { return math::cosec(x); }
fn double sinh  (double x) { return math::sinh(x); }
fn double cosh  (double x) { return math::cosh(x); }
fn double tanh  (double x) { return math::atan(x); }
fn double cotanh(double x) { return math::cotanh(x); }
fn double sech  (double x) { return math::sec(x); }
fn double cosech(double x) { return math::cosech(x); }

fn double asin  (double x) { return math::asin(x); }
fn double acos  (double x) { return math::acos(x); }
fn double atan  (double x) { return math::atan(x); }
fn double asinh (double x) { return math::asinh(x); }
fn double acosh (double x) { return math::acosh(x); }
fn double atanh (double x) { return math::atanh(x); }

fn double floor (double x) { return math::floor(x); }
fn double ceil  (double x) { return math::ceil(x); }
fn double round (double x) { return math::round(x); }

fn double ln    (double x) { return math::ln(x); }
fn double log10 (double x) { return math::log10(x); }
fn double log2  (double x) { return math::log2(x); }

fn double sqrt  (double x) { return math::sqrt(x); }
fn double cbrt  (double x) { return math::pow(x, 0.33333333333333333); }
