# YTT Playground

This is an example of processing YAML data using the Python-like "Starlark" language embedded within YTT, instead of directly in YTT itself.

The only YTT in this project is that which is required in order to take the entire YAML input to YTT,
pass it to Starlark for processing, and then use the Starlark code's output as the output of the YTT.

Schematically:

Input -> YTT no-op -> Starlark transform -> YTT no-op -> Output

The motivations behind this are:
1. YTT appears to be mostly undocumented, whereas this code at least has inline comments explaining it.
1. YTT is on obscure technology, that most people I encounter are not familiar with, and are not interested in learning about, because it is not a transportable skill.<br />
   By contrast, Starlark is fairly similar to Python (on which it was based), and
   Python is a widely-known and widely applicable language. Python skills are transportable.
1. I can't see a way to debug YTT. It just outputs the wrong thing, with little to no indication why.<br />
   In particular, in Starlark code one can output intermediate values, which I can't see how to do using YTT.
1. The YTT executable's diagnostic outputs contain incorrect line numbers, which makes debugging one's YTT code very difficult.<br />
   This project doesn't actually solve that problem, but it does allow one to insert HERE 1, HERE 2 etc
   debugging prints in the middle of the Starlark, yielding a (very primitive) method of figuring
   out where a problem is being introduced.
