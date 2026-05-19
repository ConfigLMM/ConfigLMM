<div align="center">
  <a href="https://ttytoolkit.org"><img width="130" src="https://github.com/piotrmurach/tty/raw/master/images/tty.png" alt="TTY Toolkit logo"/></a>
</div>

# TTY::Option

[![Gem Version](https://badge.fury.io/rb/tty-option.svg)][gem]
[![Actions CI](https://github.com/piotrmurach/tty-option/workflows/CI/badge.svg?branch=master)][gh_actions_ci]
[![Build status](https://ci.appveyor.com/api/projects/status/gxml9ttyvgpeasy5?svg=true)][appveyor]
[![Maintainability](https://api.codeclimate.com/v1/badges/1083a2fd114d6faf5d65/maintainability)][codeclimate]
[![Coverage Status](https://coveralls.io/repos/github/piotrmurach/tty-option/badge.svg)][coverage]

[gem]: https://badge.fury.io/rb/tty-option
[gh_actions_ci]: https://github.com/piotrmurach/tty-option/actions?query=workflow%3ACI
[appveyor]: https://ci.appveyor.com/project/piotrmurach/tty-option
[codeclimate]: https://codeclimate.com/github/piotrmurach/tty-option/maintainability
[coverage]: https://coveralls.io/github/piotrmurach/tty-option

> Parser for command line arguments, keywords, options and environment variables

## Features

* Parse command line **arguments**, **keywords**, **flags**, **options**
and **environment variables**.
* Define command line parameters with **DSL** or **keyword arguments**.
* Access all parameter values from hash-like **params**.
* Define **global parameters** with inheritance.
* Accept command line parameters in **any order**.
* Handle complex inputs like **lists** and **maps**.
* **Convert** inputs to basic and more complex object types.
* Generate **help** from parameter definitions.
* Customise help with **usage** methods such as **header**, **example** and more.
* Collect parsing **errors** for a better user experience.

## Installation

Add this line to your application's Gemfile:

```ruby
gem "tty-option"
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install tty-option

## Contents

* [1. Usage](#1-usage)
* [2. API](#2-api)
  * [2.1 argument](#21-argument)
  * [2.2 keyword](#22-keyword)
  * [2.3 option](#23-option)
  * [2.4 environment](#24-environment)
  * [2.5 parameter settings](#25-parameter-settings)
    * [2.5.1 arity](#251-arity)
    * [2.5.2 convert](#252-convert)
    * [2.5.3 default](#253-default)
    * [2.5.4 description](#254-description)
    * [2.5.5 hidden](#255-hidden)
    * [2.5.6 long](#256-long)
    * [2.5.7 name](#257-name)
    * [2.5.8 optional](#258-optional)
    * [2.5.9 permit](#259-permit)
    * [2.5.10 required](#2510-required)
    * [2.5.11 short](#2511-short)
    * [2.5.12 validate](#2512-validate)
  * [2.6 parse](#26-parse)
    * [2.6.1 :raise_on_parse_error](#261-raise_on_parse_error)
    * [2.6.2 :check_invalid_params](#262-check_invalid_params)
  * [2.7 params](#27-params)
    * [2.7.1 errors](#271-errors)
    * [2.7.2 remaining](#272-remaining)
    * [2.7.3 valid?](#273-valid)
  * [2.8 usage](#28-usage)
    * [2.8.1 header](#281-header)
    * [2.8.2 program](#282-program)
    * [2.8.3 command](#283-command)
    * [2.8.4 banner](#284-banner)
    * [2.8.5 description](#285-description)
    * [2.8.6 example](#286-example)
    * [2.8.7 footer](#287-footer)
  * [2.9 help](#29-help)
    * [2.9.1 sections](#291-sections)
    * [2.9.2 :indent](#292-indent)
    * [2.9.3 :order](#293-order)
    * [2.9.4 :param_display](#294-param_display)
    * [2.9.5 :width](#295-width)

## 1. Usage

Include the `TTY::Option` module and define parameters to parse command
line input.

Choose from [arguments](#21-argument), [keywords](#22-keyword),
[flags](#23-option), [options](#23-option) and
[environment variables](#24-environment).

For example, here is a quick demo of how to create a command that mixes
all parameter types:

```ruby
class Command
  include TTY::Option

  usage do
    program "dock"

    command "run"

    desc "Run a command in a new container"

    example "Set working directory (-w)",
            "  $ dock run -w /path/to/dir/ ubuntu pwd"

    example <<~EOS
    Mount volume
      $ dock run -v `pwd`:`pwd` -w `pwd` ubuntu pwd
    EOS
  end

  argument :image do
    required
    desc "The name of the image to use"
  end

  argument :command do
    optional
    desc "The command to run inside the image"
  end

  keyword :restart do
    default "no"
    permit %w[no on-failure always unless-stopped]
    desc "Restart policy to apply when a container exits"
  end

  flag :detach do
    short "-d"
    long "--detach"
    desc "Run container in background and print container ID"
  end

  flag :help do
    short "-h"
    long "--help"
    desc "Print usage"
  end

  option :name do
    required
    long "--name string"
    desc "Assign a name to the container"
  end

  option :port do
    arity one_or_more
    short "-p"
    long "--publish list"
    convert :list
    desc "Publish a container's port(s) to the host"
  end

  def run
    if params[:help]
      print help
    elsif params.errors.any?
      puts params.errors.summary
    else
      pp params.to_h
    end
  end
end
```

Then create a command instance:

```ruby
cmd = Command.new
```

And given the following input on the command line:

```
restart=always -d -p 5000:3000 5001:8080 --name web ubuntu:16.4 bash
```

Read the command line input (aka `ARGV`) with [parse](#26-parse):

```ruby
cmd.parse
```

Or provide an array of inputs:

```ruby
cmd.parse(%w[restart=always -d -p 5000:3000 5001:8080 --name web ubuntu:16.4 bash])
```

Finally, run the command to see parsed values:

```ruby
cmd.run
# =>
# {:help=>false,
#  :detach=>true,
#  :port=>["5000:3000", "5001:8080"],
#  :name=>"web",
#  :restart=>"always",
#  :image=>"ubuntu:16.4",
#  :command=>"bash"}
```

Use the [params](#27-params) to access all parameters:

```ruby
cmd.params[:name]     # => "web"
cmd.params["command"] # => "bash
```

Given the `--help` flag on the command line:

```ruby
cmd.parse(%w[--help])
```

Use the [help](#29-help) method to print help information to the terminal:

```ruby
print cmd.help
```

This will result in the following output:

```
Usage: dock run [OPTIONS] IMAGE [COMMAND] [RESTART=RESTART]

Run a command in a new container

Arguments:
  IMAGE    The name of the image to use
  COMMAND  The command to run inside the image

Keywords:
  RESTART=RESTART  Restart policy to apply when a container exits (permitted:
                   no, on-failure, always, unless-stopped) (default "no")

Options:
  -d, --detach        Run container in background and print container ID
  -h, --help          Print usage
      --name string   Assign a name to the container
  -p, --publish list  Publish a container's port(s) to the host

Examples:
  Set working directory (-w)
    $ dock run -w /path/to/dir/ ubuntu pwd

  Mount volume
    $ dock run -v `pwd`:`pwd` -w `pwd` ubuntu pwd
```

Given an invalid command line input:

```ruby
cmd.parse(%w[--unknown])
```

Use the [errors](#271-errors) method to print all errors:

```ruby
puts params.errors.summary
```

This will print a summary of all errors:

```
Errors:
  1) Invalid option '--unknown'
  2) Option '--publish' should appear at least 1 time but appeared 0 times
  3) Option '--name' must be provided
  4) Argument 'image' must be provided
```

## 2. API

### 2.1 argument

Use the `argument` method to parse positional arguments.

Provide a name as a string or symbol to define an argument. The name will
serve as a default label for the help display and a key to retrieve
a value from the [params](#27-params):

```ruby
argument :foo
```

Given the following command line input:

```
11 12 13
```

This would result only in one argument parsed and the remaining ignored:

```ruby
params[:foo] # => "11"
```

The `argument` method accepts a block to define
[parameter settings](#25-parameter-settings).

For example, use the [arity](#251-arity) and [convert](#252-convert) settings
to parse many positional arguments:

```ruby
argument :foo do
  name "foo(int)"             # name for help display
  arity one_or_more           # how many times can appear
  convert :int_list           # convert input to a list of integers
  validate ->(v) { v < 14 }   # validation rule
  desc "Argument description" # description for help display
end
```

Parser would collect all values and convert them to integers given
previous input:

```ruby
params[:foo] # => [11, 12, 13]
```

The `argument` method can also accept settings as keyword arguments:

```ruby
argument :foo,
  name: "foo(int)",
  arity: "+",
  convert: :int_list,
  validate: ->(v) { v < 14 },
  desc: "Argument description"
```

### 2.2 keyword

Use the `keyword` method to parse keyword arguments.

Provide a name as a string or symbol to define a keyword argument. The name
will serve as a command line input name, a default label for the help
display and a key to retrieve a value from the [params](#27-params):

```ruby
keyword :foo
```

Parser will use the parameter name to match the input name on the command
line by default.

Given the following command line input:

```
foo=11
```

This would result in:

```ruby
params[:foo] # => "11"
```

Note that the parser performs no conversion of the value.

The `keyword` method accepts a block to define
[parameter settings](#25-parameter-settings).

For example, use the [arity](#251-arity) and [convert](#252-convert)
settings to parse many keyword arguments:

```ruby
keyword :foo do
  required                   # by default keyword is not required
  arity one_or_more          # how many times can appear
  convert :int_list          # convert input to a list of integers
  validate ->(v) { v < 14 }  # validation rule
  desc "Keyword description" # description for help display
end
```

Given the following command line input:

```
foo=10,11 foo=12 13
```

This would result in an array of integers:

```ruby
params[:foo] # => [10, 11, 12, 13]
```

The `keyword` method can also accept settings as keyword arguments:

```ruby
keyword :foo,
  required: true,
  arity: :+,
  convert: :int_list,
  validate: ->(v) { v < 14 },
  desc: "Keyword description"
```

### 2.3 option

Use the `flag` or `option` methods to parse options.

Provide a name as a string or symbol to define an option. The name will
serve as a command line input name, a label for the help display and
a key to retrieve a value from the [params](#27-params):

```ruby
option :foo
```

Parser will use the parameter name to generate a long option name by default.

Given the following command line input:

```
--foo
```

This would result in:

```ruby
params[:foo] # => true
```

The `flag` and `option` methods accept a block to define
[parameter settings](#25-parameter-settings).

For example, to specify a different name for the parsed option,
use the [short](#2511-short) and [long](#256-long) settings:

```ruby
option :foo do
  short "-f"    # define a short name
  long "--foo"  # define a long name
end
```

Given the following short name on the command line:

```
-f
```

This would result in:

```
params[:foo] # => true
```

An option can accept an argument. The argument can be either required
or optional. To define a required argument, provide an extra label
in `short` or `long` settings. The label can be any string. When
both `short` and `long` names are present, only specify an argument
for the long name.

For example, for both short and long names to accept a required
integer argument:

```ruby
option :foo do
  short "-f"
  long "--foo int"
  # or
  long "--foo=int"
end
```

Given the following command line input:

```
--foo=11
```

This would result in:

```ruby
params[:foo] # => "11"
```

Note that the parser performs no conversion of the argument.

To define an optional argument, surround it with square brackets.

For example, to accept an optional integer argument:

```ruby
option :foo do
  long "--foo [int]"
end
```

Use the [arity](#251-arity) and [convert](#252-convert) settings to parse
many options given as a list of integers:

```ruby
option :foo do
  required                   # by default option is not required
  arity one_or_more          # how many times option can appear
  short "-f"                 # declare a short flag name
  long "--foo ints"          # declare a long flag with a required argument
  convert :int_list          # convert input to a list of integers
  validate ->(v) { v < 14 }  # validation rule
  desc "Option description"  # description for help display
end
```

Given the following command line input:

```
--foo=10,11 -f 12 13
```

This would result in an array of integers:

```ruby
params[:foo] # => [10, 11, 12, 13]
```

The option method can also accept settings as keyword arguments:

```ruby
option :foo,
  required: true,
  arity: :+,
  short: "-f",
  long: "--foo ints",
  convert: :int_list,
  validate: -> { |v| v < 14 },
  desc: "Option description"
```

There is a convenience `flag` method to specify a command line option that
accepts no argument:

```ruby
flag :foo
```

For example, a typical scenario is to specify the help flag:

```ruby
flag :help do
  short "-h"
  long "--help"
  desc "Print usage"
end
```

### 2.4 environment

Use the `environment` or `env` methods to parse environment variables.

Provide a name as a string or symbol to define an environment variable.
The name will serve as a command line input name, a default label for the
help display and a key to retrieve a value from the [params](#27-params):

```ruby
environment :foo
# or
env :foo
```

Parser will use the parameter name to match the input name on the command
line by default.

Given the following command line input:

```
FOO=11
```

The result would be:

```ruby
params[:foo] # => "11"
```

Note that the parser performs no conversion of the value.

The `environment` method accepts a block to define
[parameter settings](#25-parameter-settings).

For example, use the [name](#257-name) setting to change a default
variable name:

```ruby
environment :foo do
  name "FOO_ENV"
end
```

Given the following command line input:

```
FOO_ENV=11
```

This would result in:

```ruby
params[:foo] # => "11"
```

For example, use the [arity](#251-arity) and [convert](#252-convert) settings
to parse many environment variables given as a list of integers:

```ruby
environment :foo do
  required                        # by default environment is not required
  arity one_or_more               # how many times env var can appear
  name "FOO_ENV"                  # the command line input name
  convert :int_list               # convert input to a map of integers
  validate ->(v) { v < 14 }       # validation rule
  desc "Environment description"  # description for help display
end
```

Given the following command line input:

```
FOO_ENV=10,11 FOO_ENV=12 13
```

This would result in an array of integers:

```ruby
params[:foo] # => [10, 11, 12, 13]
```

The `environment` method can also accept settings as keyword arguments:

```ruby
environment :foo,
  required: true,
  arity: :+,
  name: "FOO_ENV",
  convert: :int_list,
  validate: ->(v) { v < 14 },
  desc: "Environment description"
```

### 2.5 parameter settings

All parameter types support the following settings except for
`short` and `long`, which are [option](#23-option) specific.

#### 2.5.1 arity

Use the `arity` setting to describe how many times a given parameter may
appear on the command line.

Every parameter can appear only once by default. In the case of arguments,
the parser will match the first input and ignore the rest. For other
parameter types, any extra parameter occurrence will override previously
parsed input. Setting the arity requirement overrides this behaviour.

For example, to match an argument exactly two times:

```ruby
argument :foo do
  arity 2
end
```

Given the following command line input:

```ruby
bar baz
```

This would result in an array of strings:

```ruby
params[:foo] # => ["bar", "baz"]
```

Another example is to match exactly three occurrences of a keyword:

```ruby
keyword :foo do
  arity 3
end
```

And then given the following on the command line:

```
foo=1 foo=2 foo=3
```

This would result in an array of strings:

```ruby
params[:foo] # => ["1", "2", "3"]
```

Use `:any`, `:*`, `-1`, `any` or `zero_or_more` to specify that parameter
may appear any number of times.

For example, to expect an argument to appear zero or more times:

```ruby
argument :foo do
  arity zero_or_more
end
```

Use `:+` or `one_or_more` to specify that parameter must appear at least once.

For example, to expect an option with an argument to appear one or more times:

```ruby
option :foo do
  arity one_or_more
  short "-f"
  long "--foo string"
end
```

Use `at_least` to specify the least number of times a parameter can appear:

For example, to expect a keyword to appear at least three times:

```ruby
keyword :foo do
  arity at_least(3)
end
```

The [help](#29-help) method will handle the arity for the usage banner.

For example, given the following argument definition:

```ruby
argument :foo do
  arity one_or_more
end
```

The usage banner would display:

```
Usage: foobar FOO [FOO...]
```

#### 2.5.2 convert

Use the `convert` setting to transform any parameter argument to another type.

The `convert` accepts a conversion name as a predefined symbol or class.

For example, to convert an argument to an integer:

```ruby
argument :foo do
  convert :int
  # or
  convert Integer
end
```

The supported conversion types are:

* `:bool` or `:boolean` - e.g. `yes,1,y,t` becomes `true`,
`no,0,n,f` becomes `false`
* `:date` - e.g. `28/03/2020` becomes `#<Date: 2020-03-28...>`
* `:float` - e.g. `-1` becomes `-1.0`
* `:int` or `:integer` - e.g. `+1` becomes `1`
* `:path` or `:pathname` - e.g. `/foo/bar/baz` becomes
`#<Pathname:/foo/bar/baz>`
* `:regex` or `:regexp` - e.g. `foo|bar` becomes `/foo|bar/`
* `:uri` - e.g. `foo.com` becomes `#<URI::Generic foo.com>`
* `:sym` or `:symbol` - e.g. `foo` becomes `:foo`
* `:list` or `:array` - e.g. `a,b,c` becomes `["a", "b", "c"]`
* `:map` or `:hash` - e.g. `a:1 b:2 c:3` becomes `{a: "1", b: "2", c: "3"}`

To convert to an array of a given type, specify plural or append an `array`
or`list` to any base type:

* `:bools`, `:bool_array` or `:bool_list` - e.g. `t,f,t` becomes
`[true, false, true]`
* `:floats`, `:float_array` or `:float_list` - e.g. `1,2,3` becomes
`[1.0, 2.0, 3.0]`
* `:ints`, `:int_array` or `:int_list` - e.g. `1,2,3` becomes `[1, 2, 3]`

Or, use the `list_of` method and pass the type as a first argument.

To convert to a hash with values of a given type, append a `hash` or `map` to
any base type:

* `:bool_hash` or `:bool_map` - e.g `a:t b:f c:t` becomes
`{a: true, b: false, c: true}`
* `:float_hash` or `:float_map` - e.g `a:1 b:2 c:3` becomes
`{a: 1.0, b: 2.0, c: 3.0}`
* `:int_hash` or `:int_map` - e.g `a:1 b:2 c:3` becomes `{a: 1, b: 2, c: 3}`

Or, use the `map_of` method and pass the type as a first argument.

For example, given options with a required list and map arguments:

```ruby
option :foo do
  long "--foo list"
  convert :bools
  # or
  convert list_of(:bool)
end

option :bar do
  long "--bar map"
  convert :int_map
  # or
  convert map_of(:int)
end
```

And then parsing the following command line input:

```
--foo t,f,t --bar a:1 b:2 c:3
```

This would result in an array of booleans and a hash with integer values:

```ruby
params[:foo] # => [true, false, true]
params[:bar] # => {:a=>1, :b=>2, :c=>3}
```

Use a `Proc` object to define custom conversion.

For example, to convert the command line input to uppercase:

```ruby
option :foo do
  long "--foo string"
  convert ->(val) { val.upcase }
end
```

#### 2.5.3 default

Use the `default` setting to specify a default value for an optional parameter.
The parser will use default when the command line input isn't present.

For example, given the following option definition:

```ruby
option :foo do
  long "--foo string"
  default "bar"
end
```

When the option `--foo` isn't present on the command line, the `params`
will have a default value set:

```ruby
params[:foo] # => "bar"
```

Or, use a `Proc` object to specify a default value:

```ruby
option :foo do
  long "--foo string"
  default -> { "bar" }
end
```

A parameter cannot be both required and have a default value. This will raise
`ConfigurationError`. The parser treats positional arguments as required.
To have a default for a required argument make it [optional](#258-optional):

```ruby
argument :foo do
  optional
  default "bar"
  desc "Argument description"
end
```

The usage description for a given parameter will display the default value:

```
Usage: foobar [FOO]

Arguments:
  FOO  Argument description (default "bar")
```

#### 2.5.4 description

Use the `description` or `desc` setting to provide a summary for
a parameter. The [help](#29-help) method uses a parameter
description to generate a usage display.

For example, given an option with a description:

```ruby
option :foo do
  desc "Option description"
end
```

This will result in the following help display:

```
Usage: foobar [OPTIONS]

Options:
  --foo  Option description
```

#### 2.5.5 hidden

Use the `hidden` setting to hide a parameter from the [help](#29-help) display.

For example, given a standard argument and a hidden one:

```ruby
argument :foo

argument :bar do
  hidden
end
```

The above will hide the `:bar` parameter from the usage banner:

```
Usage: foobar FOO
```

#### 2.5.6 long

Only [flag](#23-option) and [option](#23-option) parameters can use
the `long` setting.

Use the `long` setting to define a long name for an option. By convention,
a long name uses a double dash followed by many characters.

When you don't specify a short or long name, the parameter name
will serve as the option's long name by default.

For example, to define the `--foo` option:

```ruby
option :foo
```

To change the default name to the `--fuu` option:

```ruby
option :foo do
  long "--fuu"
end
```

A long option can accept an argument. The argument can be either required
or optional. To define a required argument, separate it from the option
name with a space or an equal sign.

For the `:foo` option to accept a required integer argument:

```ruby
option :foo do
  long "--foo int"
end
```

These are all equivalent ways to define a long option with a required
argument:

```ruby
long "--foo int"
long "--foo=int"
```

To define an optional argument, surround it with square brackets. Like
the required argument, separate it from the option name with a space
or an equal sign. It is possible to skip the space, but that would
make the option description hard to read.

For the `:foo` option to accept an optional integer argument:

```ruby
option :foo do
  long "--foo [int]"
end
```

These are all equivalent ways to define a long option with
an optional argument:

```ruby
long "--foo [int]"
long "--foo=[int]"
long "--foo[int]"
```

When specifying short and long option names, only define the argument
for the long name.

For example, to define an option with short and long names that accepts
a required integer argument:

```ruby
option :foo do
  short "-f"
  long "--foo int"
end
```

Note that the parser performs no conversion of the argument. Use the
[convert](#252-convert) setting to transform the argument type.

#### 2.5.7 name

The parser will use a parameter name to match command line inputs by default.
It will convert underscores in a name into dashes when matching input.

For example, given the `:foo_bar` keyword definition:

```ruby
keyword :foo_bar
```

And the following command line input:

```
foo-bar=baz
```

This would result in:

```ruby
params[:foo_bar] # => "baz"
```

Use the `name` setting to change the parameter default input name.

```ruby
keyword :foo_bar do
  name "fum"
end
```

Given the following command line input:

```
fum=baz
```

This would result in:

```ruby
params[:foo_bar] # => "baz"
```

Use uppercase characters when changing the input name for
environment variables:

```ruby
env :foo do
  name "FOO_VAR"
end
```

#### 2.5.8 optional

All parameters are optional apart from positional arguments.

Use the `optional` setting to mark a parameter as optional.

For example, given a required argument and an optional one:

```ruby
argument :foo do
  desc "Foo argument description"
end

argument :bar do
  optional
  desc "Bar argument description"
end
```

And given the following command line input:

```
baz
```

This would result in:

```ruby
params[:foo] # => "baz"
params[:bar] # => nil
```

The usage banner will display an optional argument surrounded by brackets:

```
Usage: foobar FOO [BAR]

Arguments:
  FOO  Foo argument description
  BAR  Bar argument description
```

#### 2.5.9 permit

Use the `permit` setting to restrict input to a set of possible values.

For example, to restrict the `:foo` option to only `"bar"` and `"baz"` strings:

```ruby
option :foo do
  long "--foo string"
  permit %w[bar baz]
end
```

Given the following command line input:

```
--foo bar
```

This would result in:

```ruby
params[:foo] # => "bar"
```

Given not permitted value `qux` on the command line:

```
--foo qux
```

This would raise a `TTY::Option::UnpermittedArgument` error and
make the [params](#27-params) invalid.

The parser checks permitted values after applying conversion first. Because
of this, permit setting needs its values to be already of the correct type.

For example, given integer conversion, permitted values need to
be integers as well:

```ruby
option :foo do
  long "--foo int"
  convert :int
  permit [11, 12, 13]
end
```

Then given not permitted integer:

```
--foo 14
```

This would invalidate `params` and collect the
`TTY::Option::UnpermittedArgument` error.

The [help](#29-help) method displays permitted values in the
parameter description.

For example, given the following option:

```ruby
option :foo do
  short "-f"
  long "--foo string"
  permit %w[a b c d]
  desc "Option description"
end
```

Then the description for the option would be:

```
Usage: foobar [OPTIONS]

Options:
  -f, --foo string  Option description (permitted: a, b, c, d)
```

#### 2.5.10 required

Parser only requires arguments to be present on the command line by default.
Any other parameters like options, keywords and environment variables
are optional.

Use the `required` setting to force parameter presence in command line input.

For example, given a required keyword and an optional one:

```ruby
keyword :foo do
  required
  desc "Foo keyword description"
end

keyword :bar do
  desc "Bar keyword description"
end
```

And given the following command line input:

```
foo=baz
```

This would result in:

```ruby
params[:foo] # => "baz"
params[:bar] # => nil
```

Given the following command line input without the `foo` keyword:

```
bar=baz
```

This would raise a `TTY::Option::MissingParameter` error.

Then printing [errors](#271-errors) summary would display the following
error description:

```
Error: keyword 'foo' must be provided
```

The usage banner displays the required parameters first. Then surrounds any
optional parameters in brackets.

The [help](#29-help) display for the above keywords would be:

```
Usage: foobar FOO=FOO [BAR=BAR]

Keywords:
  FOO=FOO  Foo keyword description
  BAR=BAR  Bar keyword description
```

#### 2.5.11 short

Only [flag](#23-option) and [option](#23-option) parameters can use
the `short` setting.

Use the `short` setting to define a short name for an option. By convention,
a short name uses a single dash followed by a single alphanumeric character.

For example, to define the `-f` option:

```ruby
option :foo do
  short "-f"
end
```

A short option can accept an argument. The argument can be either required
or optional. To define a required argument, separate it from the option
name with a space or an equal sign. It is possible to skip the space,
but that would make the option description hard to read.

For the `:foo` option to accept a required integer argument:

```ruby
option :foo do
  short "-f int"
end
```

These are all equivalent ways to define a short option with a required
argument:

```ruby
short "-f int"
short "-f=int"
short "-fint"
```

To define an optional argument, surround it with square brackets. Like
the required argument, separate it from the option name with a space
or an equal sign. It is possible to skip the space, but that would
make the option description hard to read.

For the `:foo` option to accept an optional integer argument:

```ruby
option :foo do
  short "-f [int]"
end
```

These are all equivalent ways to define a short option with
an optional argument:

```ruby
short "-f [int]"
short "-f=[int]"
short "-f[int]"
```

When specifying short and long option names, only define the argument
for the long name.

For example, to define an option with short and long names that accepts
a required integer argument:

```ruby
option :foo do
  short "-f"
  long "--foo int"
end
```

Note that the parser performs no conversion of the argument. Use
the [convert](#252-convert) setting to transform the argument type.

#### 2.5.12 validate

Use the `validate` setting to ensure that inputs match a validation rule.
The rule can be a string, a regular expression or a `Proc` object.

For example, to ensure the `--foo` option only accepts digits:

```ruby
option :foo do
  long "--foo int"
  validate "\d+"
end
```

Given the following command line input:

```
--foo bar
```

This would raise a `TTY::Option::InvalidArgument` error that would
make `params` invalid.

Then printing [errors](#271-errors) summary would output:

```
Error: value of `bar` fails validation for '--foo' option
```

To define a validation rule as a `Proc` object that accepts
an argument to check:

```ruby
keyword :foo do
  convert :int
  validate ->(val) { val < 12 }
end
```

The parser validates a value after applying conversion first. Because of
this, the value inside a validation rule is already of the correct type.

Given the following command line input:

```
foo=13
```

This would raise a `TTY::Option::InvalidArgument` error and make
`params` invalid.

Then using the [errors](#271-errors) summary would print the following error:

```
Error: value of `13` fails validation for 'foo' keyword
```

### 2.6 parse

Use the `parse` method to match command line inputs against defined parameters.

The `parse` method reads the input from the command line (aka `ARGV`) and
the environment variables (aka `ENV`) by default. It also accepts inputs
as an argument. This is useful when testing commands.

For example, given the following parameter definitions:

```ruby
argument :foo

flag :bar

keyword :baz

env :qux
```

Then parsing the command line inputs:

```ruby
parse(%w[12 --bar baz=a QUX=b])
```

This would result in:

```ruby
params[:foo] # => "12"
params[:bar] # => true
params[:baz] # => "a"
params[:qux] # => "b"
```

The parser doesn't force any order for the parameters except for arguments.

For example, reordering inputs for the previous parameter definitions:

```ruby
parse(%w[12 QUX=b --bar baz=a])
```

This would result in the same values:

```ruby
params[:foo] # => "12"
params[:bar] # => true
params[:baz] # => "a"
params[:qux] # => "b"
```

The parser handles compact shorthand options that start with
a single dash. These must be boolean options except for
the last one that can accept an argument.

For example, passing three flags and an option with an argument to parse:

```
parse(%w[-f -b -q -s 12])
```

This is equivalent to parsing:

```
parse(%w[-fbqs 12])
```

Parameter parsing stops at the `--` terminator. The parser collects leftover
inputs and makes them accessible with the [remaining](#272-remaining) method.

For example, given extra input after the terminator:

```ruby
parse(%w[12 baz=a QUX=b -- --fum])
```

This would result in:

```ruby
params[:foo] # => 12
params[:bar] # => false
params[:baz] # => "a"
params[:qux] # => "b"
params.remaining # => ["--fum"]
```

#### 2.6.1 :raise_on_parse_error

The `parse` method doesn't raise any errors by default. Why? Displaying
error backtraces in the terminal output may not be helpful for users.
Instead, the parser collects any errors and exposes them through the
[errors](#271-errors) method.

Use the `:raise_on_parse_error` keyword set to `true` to raise parsing errors:

```ruby
parse(raise_on_parse_error: true)
```

Parsing errors inherit from `TTY::Option::ParseError`.

For example, to catch parsing errors:

```ruby
begin
  parse(raise_on_parse_error: true)
rescue TTY::Option::ParseError => err
  ...
end
```

#### 2.6.2 :check_invalid_params

Users can provide any input, including parameters the parser
didn't expect and define.

When the parser finds an unknown input on the command line, it raises
a `TTY::Option::InvalidParameter` error and adds it to the
[errors](#271-errors) array.

Use the `:check_invalid_params` keyword set to `false` to ignore unknown
inputs during parsing:

```ruby
parse(check_invalid_params: false)
```

This way, the parser will collect all the unrecognised inputs into the
[remaining](#272-remaining) array.

### 2.7 params

All defined parameters are accessible from the `params` object.

The `params` object behaves like a hash with indifferent access. It doesn't
differentiate between arguments, keywords, options or environment variables.
Because of that, each parameter needs to have a unique name.

For example, given a command with all parameter types:

```ruby
class Command
  include TTY::Option

  argument :foo

  keyword :bar

  option :baz do
    long "--baz string"
  end

  env :qux

  def run
    print params[:foo]
    print params["bar"]
    print params["baz"]
    print params[:qux]
  end
end
```

And the following command line input:

```
a bar=b --baz c QUX=d
```

Then instantiating the command:

```ruby
cmd = Command.new
```

And parsing command line input:

```ruby
cmd.parse
```

And running the command:

```ruby
cmd.run
```

This would result in the following output:

```
abcd
```

#### 2.7.1 errors

The `parse` method only raises configuration errors. The parsing errors are
not raised by default. Instead, the `errors` method on the `params` object
gives access to any parsing error.

```ruby
params.errors # => TTY::Option::AggregateErrors
```

The `errors` method returns an `TTY::Option::AggregateErrors` object that
is an `Enumerable`.

For example, to iterate over all the errors:

```ruby
params.errors.each do |error|
  ...
end
```

The `TTY::Option::AggregateErrors` object has the following
convenience methods:

* `messages` - an array of all error messages
* `summary` - a string of formatted error messages ready to display
in the terminal

For example, given an argument that needs to appear at least two times in
the command line input:

```ruby
argument :foo do
  arity at_least(2)
end
```

And parsing only one argument from the command line input:

```ruby
parse(%w[12])
```

Then printing errors summary:

```ruby
puts params.errors.summary
```

This would print the following error message:

```
Error: argument 'foo' should appear at least 2 times but appeared 1 time
```

Adding integer conversion to the previous example:

```ruby
argument :foo do
  arity at_least(2)
  convert :int
end
```

And given only one invalid argument to parse:

```ruby
parse(%w[zzz])
```

The summary would be:

```
Errors:
  1) Argument 'foo' should appear at least 2 times but appeared 1 time
  2) Cannot convert value of `zzz` into 'int' type for 'foo' argument
```

Use the [:raise_on_parse_error](#261-raise_on_parse_error) keyword to raise
parsing errors on invalid input.

Consider using the [tty-exit](https://github.com/piotrmurach/tty-exit) gem
for more expressive exit code reporting.

For example, the `TTY::Exit` module provides the `exit_with` method:

```ruby
class Command
  include TTY::Exit
  include TTY::Option

  def run
    if params.errors.any?
      exit_with(:usage_error, params.errors.summary)
    end
    ...
  end
end
```

#### 2.7.2 remaining

When the parser finds an unknown input on the command line, it raises
a `TTY::Option::InvalidParameter` error and adds it to the
[errors](#271-errors) array.

Use the [:check_invalid_params](#262-check_invalid_params) keyword
set to `false` to ignore unknown inputs during parsing:

```ruby
parse(check_invalid_params: false)
```

This way, the parser will collect all the unrecognised inputs
into an array. The `remaining` method on the `params` gives access
to all invalid inputs.

For example, given an unknown option to parse:

```ruby
parse(%w[--unknown])
```

Then inspecting the `remaining` inputs:

```ruby
params.remaining # => ["--unknown"]
```

The parser leaves any inputs after the `--` terminator alone. Instead,
it collects them into the remaining array. This is useful when passing
inputs over to other command line applications.

#### 2.7.3 valid?

Use the `valid?` method to check that command line inputs meet all
validation rules.

The `valid?` method is available on the `params` object:

```ruby
params.valid? # => true
```

Use the [errors](#271-errors) method to check for any errors and not only
validation rules:

```ruby
params.errors.any?
```

### 2.8 usage

The `usage` method accepts a block that configures the
[help](#29-help) display.

#### 2.8.1 header

Use the `header` setting to display information above the banner.

For example, to explain a program's purpose:

```ruby
usage do
  header "A command line interface for foo service"
end
```

This would print:

```
A command line interface for foo service

Usage: foo [OPTIONS]
```

The `header` setting accepts many arguments, each representing a single
paragraph. An empty string displays as a new line.

For example, to create an introduction with two paragraphs separated by
an empty line:

```ruby
usage do
  header "A command line interface for foo service",
         "",
         "Access and retrieve data from foo service"
end
```

Or, add two paragraphs using the `header` setting twice:

```ruby
usage do
  header "A command line interface for foo service"

  header "Access and retrieve data from foo service"
end
```

Both would result in the same output:

```
A command line interface for foo service

Access and retrieve data from foo service

Usage: foo [OPTIONS]
```

#### 2.8.2 program

The `program` setting uses an executable file name to generate a program
name by default.

For example, to override the default name:

```ruby
usage do
  program "custom-name"
end
```

Then usage banner will display a custom program name:

```
Usage: custom-name
```

#### 2.8.3 command

The `command` setting uses a class name to generate a command name by default.
It converts a class name into a dash case.

For example, given the following command class name:

```ruby
class NetworkCreate
  include TTY::Option
end
```

The command name would become `network-create`.

Use the `command` or `commands` setting to change the default command name.

For example, to change the previous class's default command name:

```ruby
class NetworkCreate
  include TTY::Option

  usage do
    command "net-create"
  end
end
```

The usage banner would be:

```
Usage: program net-create
```

Use the `commands` setting for naming a subcommand.

For example, to add `create` command as a subcommand:

```ruby
module Network
  class Create
    include TTY::Option

    usage do
      commands "network", "create"
    end
  end
end
```

This will result in the following usage banner:

```
Usage: program network create
```

Use the `no_command` setting to skip having a command name:

```ruby
usage do
  no_command
end
```

This will display only the program name:

```
Usage: program
```

#### 2.8.4 banner

The `banner` setting combines program, command and parameter names
to generate usage banner.

For example, given the following usage and parameter definitions:

```ruby
usage do
  program "prog"

  command "cmd"
end

argument :foo

keyword :bar

option :baz

env :qux
```

Then usage banner would print as follows:

```
Usage: prog cmd [OPTIONS] [ENVIRONMENT] FOO [BAR=BAR]
```

The [help](#29-help) generator displays the usage banner first
unless a [header](#281-header) is set.

Use the `banner` setting to create a custom usage display.

For example, to change the parameters format:

```ruby
usage do
  program "prog"

  command "cmd"

  banner "Usage: #{program} #{command.first} <opts> <envs> foo [bar=bar]"
end
```

This would display as:

```
Usage: prog cmd <opts> <envs> foo [bar=bar]
```

Use the [:param_display](#294-param_display) setting to change the banner
parameters format.

#### 2.8.5 description

Use `description` or `desc` setting to display information right after
the usage banner.

For example, to give extra information:

```ruby
usage do
  desc "A description for foo service"
end
```

This would print:

```
Usage: foo [OPTIONS]

A description for foo service
```

The `desc` setting accepts many arguments, each representing a single
paragraph. An empty string displays as a new line.

For example, to create a description with two paragraphs separated by
an empty line:

```ruby
usage do
 desc "A description for foo service",
      "",
      "Learn more about foo service\nby reading tutorials"
end
```

Or, add two paragraphs using the `desc` setting twice:

```ruby
usage do
  desc "A description for foo service",

  desc <<~EOS
  Learn more about foo service
  by reading tutorials
  EOS
end
```

Both would result in the same output:

```
Usage: foo [OPTIONS]

A description for foo service

Learn more about foo service
by reading tutorials
```

#### 2.8.6 example

Use the `example` or `examples` setting to add a usage examples section
to the help display.

The `example` setting accepts many arguments, each representing a single
paragraph. An empty string displays as a new line.

For instance, to create an example usage displayed on two lines:

```ruby
usage do
  example "Some example how to use foo",
          " $ foo bar"
end
```

This will result in the following help output:

```
Examples:
  Some example how to use foo
    $ foo bar
```

Or, add two examples using the `example` setting twice:


```ruby
usage do
  example "Some example how to use foo",
          " $ foo bar"

  example <<~EOS
  Another example how to use foo"
    $ foo baz
  EOS
end
```

The examples section would display the following:

```
Examples:
  Some example how to use foo
    $ foo bar

  Another example how to use foo
    $ foo baz
```

#### 2.8.7 footer

Use the `footer` setting to display text after all information
in the usage help.

For example, to reference further help:

```ruby
usage do
  footer "Run a command followed by --help to see more info."
end
```

This would print as follows:

```
Usage: foo [OPTIONS]

Run a command followed by --help to see more info.
```

The `footer` setting accepts many arguments, each representing a single
paragraph. An empty string displays as a new line.

For example, to display further help with two paragraphs separated by
an empty line:

```ruby
usage do
  footer "Run a command followed by --help to see more info.",
         "",
         "Report bugs to the mailing list."
end
```

Or, add two paragraphs using the `footer` setting twice:

```ruby
usage do
  footer "Run a command followed by --help to see more info."

  footer "Report bugs to the mailing list."
end
```

Both would result in the same output:

```
Usage: foo [OPTIONS]

Run a command followed by --help to see more info.

Report bugs to the mailing list.
```

### 2.9 help

Use the `help` method to generate usage information about defined parameters.

The [usage](#28-usage) describes how to add different sections to the
help display.

For example, given the following command class definition with
a `run` method that prints help:


```ruby
class Command
  include TTY::Option

  usage do
    program "foobar"
    no_command
    header "foobar CLI"
    desc "CLI description"
    example "Example usage"
    footer "Run --help to see more info"
  end

  argument :foo, desc: "Argument description"
  keyword :bar, desc: "Keyword description"
  option :baz, desc: "Option description"
  env :qux, desc: "Environment description"

  flag :help do
    short "-h"
    long  "--help"
    desc "Print usage"
  end

  def run
    if params[:help]
      print help
      exit
    end
  end
end
```

Running the command with `--help` flag:

```ruby
cmd = Command.new
cmd.parse(%w[--help])
cmd.run
```

This would result in the following help display:

```
foobar CLI

Usage: foobar [OPTIONS] [ENVIRONMENT] FOO [BAR=BAR]

CLI description

Arguments:
  FOO  Argument description

Keywords:
  BAR=BAR  Keyword description

Options:
      --baz   Option description
  -h, --help  Print usage

Environment:
  QUX  Environment description

Examples:
  Example usage

Run --help to see more info
```

#### 2.9.1 sections

Pass a block to the `help` method to change generated usage information.
The block accepts a single argument, a `TTY::Option::Sections` object.
This object provides hash-like access to each named part of the help display.

The following are the names of all supported sections ordered by help display
from top to bottom:

* `:header`
* `:banner`
* `:description`
* `:arguments`
* `:keywords`
* `:options`
* `:environments`
* `:examples`
* `:footer`

Accessing a named section returns a `TTY::Option::Section` object
with `name` and `content` methods.

For example, to access the arguments section content:

```ruby
help do |sections|
  sections[:arguments].content # => "\nArguments:\n  FOO  Argument description"
end
```

To add a new section, use the `add_after` and `add_before` methods. These
methods accept three arguments. The first argument is the section name
to add after or before. The second argument is a new section name,
and the last is content to add.

For example, to insert a new commands section after the description:

```ruby
help do |sections|
  sections.add_after :description, :commands, <<~EOS.chomp

  Commands:
    create  Create command description
    delete  Delete command description
  EOS
end
```

Given the following usage and parameter definition:

```ruby
usage do
  program "prog"

  command "cmd"

  desc "Program description"
end

argument :foo do
  desc "Foo argument description"
end
```

The help display would be:

```
Usage: prog cmd FOO

Program description

Commands:
  create  Create command description
  delete  Delete command description

Arguments:
  FOO  Argument description
```

Use `delete` and `replace` methods to change existing sections.

For example, to remove a header section:

```ruby
help do |sections|
  sections.delete :header
end
```

Or, to replace the content of a footer section:

```ruby
help do |sections|
  sections.replace :footer, "\nReport bugs to the mailing list."
end
```

#### 2.9.2 :indent

The help output has no indentation except for displaying parameters by default.

Use the `:indent` keyword to change the indentation of the help display.

For example, to indent help display by two spaces:

```ruby
help(indent: 2)
```

#### 2.9.3 :order

The help generator orders parameters alphabetically within
each section by default.

Use the `:order` keyword to change the default ordering.

The `:order` expects a `Proc` object as a value. The `Proc` accepts
a single argument, an array of parameters within a section.

For example, to preserve the parameter definition order:

```ruby
help(order: ->(params) { params })
```

#### 2.9.4 :param_display

The usage banner displays positional and keyword arguments
in uppercase letters by default.

For example, given the following parameter definitions:

```ruby
usage do
  program "prog"
end

argument :foo, desc: "Argument description"

keyword :bar, desc: "Keyword description"

option :baz, desc: "Option description"

env :qux, desc: "Environment description"
```

The usage banner would print as follows:

```
Usage: prog [OPTIONS] [ENVIRONMENT] FOO [BAR=BAR]
```

Use the `:param_display` keyword to change the banner parameter formatting.

The `:param_display` expects a `Proc` object as a value. The `Proc` accepts
a single argument, a parameter name within a section.

For example, to lowercase and surround parameters with `<` and `>` brackets:

```ruby
help(param_display: ->(param) { "<#{param.downcase}>" })
```

This would result in the following usage banner and parameter sections:

```
Usage: prog [<options>] [<environment>] <foo> [<bar>=<bar>]

Arguments:
  <foo>  Argument description

Keywords:
  <bar>=<bar>  Keyword description

Options:
  --baz  Option description

Environment:
  QUX  Environment description
```

#### 2.9.5 :width

The help generator wraps content at the width of `80` columns by default.

Use the `:width` keyword to change it, for example, to `120` columns:

```ruby
help(width: 120)
```

Use the [tty-screen](https://github.com/piotrmurach/tty-screen) gem
to change the help display based on terminal width.

For example, to expand the help display to the full width of
the terminal window:

```ruby
help(width: TTY::Screen.width)
```

## Development

After checking out the repo, run `bin/setup` to install dependencies.
Then, run `rake spec` to run the tests. You can also run `bin/console`
for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`.
To release a new version, update the version number in `version.rb`, and then
run `bundle exec rake release`, which will create a git tag for the version,
push git commits and tags, and push the `.gem` file to
[rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at
https://github.com/piotrmurach/tty-option. This project is intended to be
a safe, welcoming space for collaboration, and contributors are expected
to adhere to the [code of conduct](https://github.com/piotrmurach/tty-option/blob/master/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the
[MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the TTY::Option project's codebases, issue trackers,
chat rooms and mailing lists is expected to follow the
[code of conduct](https://github.com/piotrmurach/tty-option/blob/master/CODE_OF_CONDUCT.md).

## Copyright

Copyright (c) 2020 Piotr Murach. See LICENSE for further details.
