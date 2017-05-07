# CSV Tool

CSV Tool lets you pretty print, add, move or remove columns from an CSV file directly from shell.

## Requirements

 * none

## Usage

    $ ./csvtool.sh "file.csv" print                       Pretty print CSV
    $ ./csvtool.sh "file.csv" print 1,2,5,6               Pretty print CSV but only columns 1, 2, 5 and 6

    $ ./csvtool.sh "file.csv" columns                     Print columns with their column indexes

    $ ./csvtool.sh "file.csv" add 3 "New column title"    Add a new column at position 3 with title "New column title"

    $ ./csvtool.sh "file.csv" remove 3                    Remove column at position 3
    $ ./csvtool.sh "file.csv" remove "Column title"       Remove column with title "Column title"

    $ ./csvtool.sh "file.csv" cut 3                       Remove all columns starting at position 3
    $ ./csvtool.sh "file.csv" cut "Column title"          Remove all columns starting at column with title "Column title"

    $ ./csvtool.sh "file.csv" move 5 3                    Move column 5 to position 3
    $ ./csvtool.sh "file.csv" move "Column title" 3       Move column with title "Column title" to position 3

    $ ./csvtool.sh "file.csv" export "target file"        Sync and export all column indexes to file "target file". Column changes will be updated, names stay untouched.

    $ ./csvtool.sh "file.csv" dot_to_comma                Replace all "." to ",".

 * Additional parameters:

    $ delimiter=,                                         Change delimiter to ","
    $ out=result.csv                                      Save changes to "result.csv"
