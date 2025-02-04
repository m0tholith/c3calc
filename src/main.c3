module calculator;

import tokenizer;
import parser;
import std::io;

const String ZERO  = "0";
const String ONE   = "1";
const String TWO   = "2";
const String THREE = "3";
const String FOUR  = "4";
const String FIVE  = "5";
const String SIX   = "6";
const String SEVEN = "7";
const String EIGHT = "8";
const String NINE  = "9";

const Primary PRIM_ZERO   = { NUMBER, ZERO,  null };
const Primary PRIM_ONE    = { NUMBER, ONE,   null };
const Primary PRIM_TWO    = { NUMBER, TWO,   null };
const Primary PRIM_THREE  = { NUMBER, THREE, null };
const Primary PRIM_FOUR   = { NUMBER, FOUR,  null };
const Primary PRIM_FIVE   = { NUMBER, FIVE,  null };
const Primary PRIM_SIX    = { NUMBER, SIX,   null };
const Primary PRIM_SEVEN  = { NUMBER, SEVEN, null };
const Primary PRIM_EIGHT  = { NUMBER, EIGHT, null };
const Primary PRIM_NINE   = { NUMBER, NINE,  null };

fn int main(String[] args)
{
    TokenList tokens = tokenizer::tokenize(args[1]);

    // Unary negSix   = { MINUS, &PRIM_SIX   };
    // Unary posThree = { PLUS,  &PRIM_THREE };
    // Unary negSeven = { MINUS, &PRIM_SEVEN };
    // Unary posNine  = { PLUS,  &PRIM_NINE  };

    // Factor negSixTimesPosThree = { &negSix, { { MUL, &posThree } } };

    // Term negSevenPlusNegSixTimesPosThree = { &&Factor { &negSeven, { } }, { { ADD, &&(Factor)negSixTimesPosThree } } };
    // io::printn(negSevenPlusNegSixTimesPosThree.toString());

    int current = 0;
    if (try eval = parser::parseTerm(tokens, &current))
    {
        io::printn("YAY!!!!!!");
        io::printn(eval.toString());
    }
    else
    {
        io::printn("ERROR!!!!");
    }

    tokens.free();
	return 0;
}
