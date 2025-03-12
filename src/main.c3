module c3calc;

import tokenizer;
import parser;
import interpreter;
import std::io;
import std::math;

fn int main(String[] args)
{
    Interpreter interpreter = interpreterInit();
    defer interpreter.free();

    if (args.len == 1)
    {
        while (true)
        {
            String! expr = io::readline(mem);
            if (catch excuse = expr) return 0;
            defer free(expr);
            if (expr == ":q") return 0;
            String! result = interpreter.execute(expr);
            if (catch excuse = result)
            {
                io::eprintfn("ERROR: %s", excuse);
                continue;
            }
            io::printn(result);
        }
    }

    foreach (arg : args[1 ..])
	{
        String! result = interpreter.execute(arg);
        if (catch excuse = result)
        {
            io::eprintfn("ERROR: %s", excuse);
            return -1;
        }
        io::printn(result);
    }

	return 0;
}

fn Interpreter interpreterInit()
{
    Interpreter interpreter;
    interpreter.init();

    interpreter.add_functions({
        { "sin", fn (x) => math::sin(x) },
        { "cos", fn (x) => math::cos(x) },
        { "tan", fn (x) => math::tan(x) },
        { "cotan", fn (x) => math::cotan(x) },
        { "sec", fn (x) => math::sec(x) },
        { "cosec", fn (x) => math::cosec(x) },
        { "sinh", fn (x) => math::sinh(x) },
        { "cosh", fn (x) => math::cosh(x) },
        { "tanh", fn (x) => math::atan(x) },
        { "cotanh", fn (x) => math::cotanh(x) },
        { "sech", fn (x) => math::sec(x) },
        { "cosech", fn (x) => math::cosech(x) },

        { "asin", fn (x) => math::asin(x) },
        { "acos", fn (x) => math::acos(x) },
        { "atan", fn (x) => math::atan(x) },
        { "asinh", fn (x) => math::asinh(x) },
        { "acosh", fn (x) => math::acosh(x) },
        { "atanh", fn (x) => math::atanh(x) },

        { "floor", fn (x) => math::floor(x) },
        { "ceil", fn (x) => math::ceil(x) },
        { "round", fn (x) => math::round(x) },

        { "ln", fn (x) => math::ln(x) },
        { "log10", fn (x) => math::log10(x) },
        { "log2", fn (x) => math::log2(x) },

        { "sqrt", fn (x) => math::sqrt(x) },
        { "cbrt", fn (x) => math::pow(x, 1.0 / 3.0) },

        { "deg2rad", fn (x) => math::deg_to_rad(x) },
        { "rad2deg", fn (x) => x / math::PI * 180.0 },
    });

    return interpreter;
}
