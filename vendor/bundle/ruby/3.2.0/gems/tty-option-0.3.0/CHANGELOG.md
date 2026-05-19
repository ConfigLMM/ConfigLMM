# Change log

## [v0.3.0] - 2023-05-29

### Changed
* Change permit setting to work with parameters converted to an array or a hash
* Change formatting of a hash value in parameter validation error message
* Change array and hash conversions to work with non-string values
* Change date conversion to work with date objects
* Change pathname conversion to only work with strings and pathname objects
* Change regexp conversion to only work with strings and regexp objects
* Change uri conversion to work with uri objects
* Change deep cloning to stop making copies of unbound methods
* Change deep cloning to copy objects with the same identity only once
* Change deep cloning to work with recursive arrays and hashes

### Fixed
* Fix argument check against permitted values to allow nil value when optional
* Fix parsing values provided with abbreviated long option names
* Fix any object type to symbol conversion failure to return an undefined value
* Fix parameter validation to stop transforming hash value into an array
* Fix help display when formatting only short options
* Fix parameter name alignment formatting to ignore hidden parameters
* Fix description alignment formatting for parameters with only default or permit
* Fix short option name alignment formatting to check whether a long name is set

## [v0.2.0] - 2021-08-04

### Added
* Add predicate methods for checking if a given parameter is supported

### Changed
* Change Conversions to stop raising error and return Undefined value instead
* Change to skip conversion of parameters with nil value

### Fixed
* Fix conversion of nil into array or hash to stop raising an error
* Fix #no_command to correctly mark command as not present
* Fix warnings about shadowing local variables

## [v0.1.0] - 2020-05-18

* Initial implementation and release

[v0.3.0]: https://github.com/piotrmurach/tty-option/compare/v0.2.0...v0.3.0
[v0.2.0]: https://github.com/piotrmurach/tty-option/compare/v0.1.0...v0.2.0
[v0.1.0]: https://github.com/piotrmurach/tty-option/compare/95179f0...v0.1.0
