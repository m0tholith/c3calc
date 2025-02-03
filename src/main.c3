module calculator;

import tokenizer;

fn int main(String[] args)
{
    TokenList tokens = tokenizer::tokenize(args[1]);

    tokens.free();
	return 0;
}
