[![Build Status](https://drone.io/github.com/christophehurpeau/dart-preprocessor/status.png)](https://drone.io/github.com/christophehurpeau/dart-preprocessor/latest)

The preprocessor parse the source code and uses comments to build different versions of the same code.

## Directives

### if [elseif ]* [ else] endif

```
/*#if DEV*/
the DEV code
/*#else*/
the PROD code
/*#/if*/

/*#if test1*/
when test1 is true
/*#elseif test2*/
when test2 is true
/*#/if*/
```

### if !

```
/*#if ! DEV*/
the PROD code
/*#else*/
the DEV code
/*#/if*/
```

### ifdef, ifndef

```
/*#ifdef var1*/
if var1 is defined
/*#/if*/

/*#ifndef var2*/
if var2 is not defined
/*#/if*/
```

### value

```
/*#ifdef blog.title*/
The title blog: /*#val blog.title*/
/*#/if*/
```

## API

```
Preprocessor p = new Preprocessor('js');
p.process({ 'DEV': true },"test(/*#val value*/0);")
  .then((String result){
  	print(result);
  });
```
