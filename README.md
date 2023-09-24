# YSL-C3
Yeti's Simple Language, Compiled

This language takes YSL concepts and throws them out the window, but at least the syntax is similar

## Build
First, clone the repository
```
git clone https://github.com/YSL-C/YSL-C3 --recursive
```
Remove --recursive if you don't want the standard library (this is required for building the examples)

Now, build the compiler

```
dub build
```

Then use `./yslc --help` to see usage

## Build examples
```
yslc examples/example.ysl -o example
```
Replace example.ysl with your chosen example

## Features
- [X] Function definitions & calls
- [X] Variables
- [X] If statements
- [X] While statements
- [X] For statements
- [X] Overloads
- [ ] Classes
- [ ] Class methods
