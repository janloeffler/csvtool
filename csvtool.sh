#!/bin/bash
#
################################################################################
##          CSV Tool to add or remove columns                                 ##
################################################################################

# ----------- SETTINGS -----------
CSV_DELIMITER=";"
TEMP_FILE="csvtool.tmp"

REGEX_DIGITS="^[0-9]+$"

unset SIMULATE
unset NEW_CSV

export LANG="en_US.utf-8"
export LC_NUMERIC="en_US.utf-8"
export LC_ALL="en_US.utf-8"

# ----------- FUNCTIONS -----------
function print_help
{
    echo

    if [[ -n $1 ]]; then
        echo "$1"
    else
        echo "CSV Tool lets you pretty print, add, move or remove columns from an CSV file directly from shell."
    fi

    echo
    echo "Usage:"
    echo "  ./csvtool.sh \"file.csv\" print                       Pretty print CSV"
    echo "  ./csvtool.sh \"file.csv\" print 1,2,5,6               Pretty print CSV but only columns 1, 2, 5 and 6"
    echo
    echo "  ./csvtool.sh \"file.csv\" columns                     Print columns with their column indexes"
    echo
    echo "  ./csvtool.sh \"file.csv\" add 3 \"New column title\"    Add a new column at position 3 with title \"New column title\""
    echo
    echo "  ./csvtool.sh \"file.csv\" remove 3                    Remove column at position 3"
    echo "  ./csvtool.sh \"file.csv\" remove \"Column title\"       Remove column with title \"Column title\""
    echo
    echo "  ./csvtool.sh \"file.csv\" cut 3                       Remove all columns starting at position 3"
    echo "  ./csvtool.sh \"file.csv\" cut \"Column title\"           Remove all columns starting at column with title \"Column title\""
    echo
    echo "  ./csvtool.sh \"file.csv\" move 5 3                    Move column 5 to position 3"
    echo "  ./csvtool.sh \"file.csv\" move \"Column title\" 3       Move column with title \"Column title\" to position 3"
    echo
    echo "  ./csvtool.sh \"file.csv\" export \"target file\"        Sync and export all column indexes to file \"target file\". Column changes will be updated, names stay untouched."
    echo
    echo "  ./csvtool.sh \"file.csv\" dot_to_comma                Replace all \".\" to \",\"."
    echo
    echo "Additional parameters:"
    echo "  delimiter=,                                           Change delimiter to \",\""
    echo "  out=result.csv                                        Save changes to \"result.csv\""
    echo
}

# Function to get the index (starting from 0) for a column header.
# Parameters: 1 File to check / 2 column header value
function get_column_index
{
    IFS=';' read -r -a COLUMNS <<< "$(head -n 1 $1)"
    i=0
    for ((i=0;i<${#COLUMNS[@]};i++)); do
        if [[ "${COLUMNS[$i]}" == "$2" ]]; then
            echo $i
            break
        fi
    done
}

function explode_columns
{
    COLS="$1,,"
    RESULT=","
    unset LAST_COL
    unset IN_RANGE
    while IFS='' read -r -d '' -n 1 char; do
        if [[ $char =~ ^[0-9]$ ]]; then
            LAST_COL+="$char"
        elif [[ $char == '-' ]]; then
            RESULT+=",$LAST_COL"
            IN_RANGE=$LAST_COL
            unset LAST_COL
        else
            if [[ -n $IN_RANGE ]]; then
                for ((i=$IN_RANGE;i<=$LAST_COL;i++)); do
                    RESULT+=",$i"
                done
                unset IN_RANGE
            else
                RESULT+=",$LAST_COL"
            fi
            unset LAST_COL
        fi
    done < <(printf %s "$COLS")

    echo $RESULT
}

# Function to remove temp file.
function clear_temp
{
    if [ -f "$TEMP_FILE" ]; then rm "$TEMP_FILE"; fi
}

# ----------- START HERE -----------
if [[ "$@" == *"--help"* ]]; then
    print_help
    exit 0
fi

CSV_FILE=$1
COMMAND=$2
OPT1=$3
OPT2=$4
OUT_CSV=$CSV_FILE

if [[ -z $CSV_FILE ]]; then
    print_help
    exit 1
fi

if [ ! -f "$CSV_FILE" ]; then
    print_help "ERROR: File \”$CSV_FILE\” not found!"
    exit 1
fi

if [[ -z $COMMAND ]]; then
    COMMAND="print"
fi

if [[ "$@" == *"SIM"* ]]; then SIMULATE="ON"; fi
if [[ "$@" == *"delimiter="* ]]; then
    for PARAM in "$@"; do
        if [[ "$PARAM" == "delimiter="* ]]; then
            CSV_DELIMITER=$(echo $PARAM | sed 's/delimiter=//')
        fi
    done
fi

if [[ "$@" == *"out="* ]]; then
    for PARAM in "$@"; do
        if [[ "$PARAM" == "out="* ]]; then
            NEW_CSV=1
            OUT_CSV=$(echo $PARAM | sed 's/out=//')
        fi
    done
fi

clear_temp

# --- print command ---
if [[ $COMMAND == "pri"* ]]; then

    if [[ -n $OPT1 ]]; then
        COLUMNS=$(explode_columns "$OPT1")
        while read -r LINE; do
            IFS=$CSV_DELIMITER read -r -a CSV <<< "$LINE"

            LINE=""
            for ((i=0;i<${#CSV[@]};i++)); do
                if [[ "$COLUMNS" == *",$i,"* ]]; then
                    LINE+="${CSV[$i]}${CSV_DELIMITER}"
                fi
            done

            echo "$LINE" | rev | cut -c 2- | rev >> "$TEMP_FILE"
        done < "$CSV_FILE"

        if [[ -n $NEW_CSV ]]; then
            cp $TEMP_FILE $OUT_CSV
        fi

        sed "s/${CSV_DELIMITER}${CSV_DELIMITER}/$CSV_DELIMITER $CSV_DELIMITER/g;s/${CSV_DELIMITER}${CSV_DELIMITER}/$CSV_DELIMITER $CSV_DELIMITER/g" $TEMP_FILE | column -s "$CSV_DELIMITER" -t
    else
        sed "s/${CSV_DELIMITER}${CSV_DELIMITER}/$CSV_DELIMITER $CSV_DELIMITER/g;s/${CSV_DELIMITER}${CSV_DELIMITER}/$CSV_DELIMITER $CSV_DELIMITER/g" $CSV_FILE | column -s "$CSV_DELIMITER" -t
    fi

# --- columns command ---
elif [[ $COMMAND == "col"* ]]; then

    IFS=$CSV_DELIMITER read -r -a CSV_HEADER <<< "$(head -n 1 $CSV_FILE)"
    for ((i=0;i<${#CSV_HEADER[@]};i++)); do
        echo "$(/usr/bin/printf "%2s" $i) ${CSV_HEADER[$i]}"
    done

# --- add command ---
elif [[ $COMMAND == "add" ]]; then

    if [[ -z $OPT1 ]] || [[ ! "$OPT1" =~ $REGEX_DIGITS ]]; then
        print_help "ERROR: 3rd parameter needs to be the column index as integer number!"
        exit 1
    fi

    COLUMN=$OPT1
    COLUMN_BEFORE=$((COLUMN - 1))
    IS_HEADER=1
    while read -r LINE; do
        IFS=$CSV_DELIMITER read -r -a CSV <<< "$LINE"

        LINE=""
        if [[ $COLUMN_BEFORE -ge 0 ]]; then
            for ((i=0;i<=${COLUMN_BEFORE};i++)); do
                LINE+="${CSV[$i]}${CSV_DELIMITER}"
            done
        fi

        if [[ -n $IS_HEADER ]]; then
            LINE+="${OPT2}${CSV_DELIMITER}"
            unset IS_HEADER
        else
            LINE+="$CSV_DELIMITER"
        fi

        for ((i=${COLUMN};i<${#CSV[@]};i++)); do
            LINE+="${CSV[$i]}${CSV_DELIMITER}"
        done

        echo "$LINE" | rev | cut -c 2- | rev >> "$TEMP_FILE"
    done < "$CSV_FILE"

    if [[ -n $SIMULATE ]]; then
        sed "s/${CSV_DELIMITER}${CSV_DELIMITER}/$CSV_DELIMITER $CSV_DELIMITER/g;s/${CSV_DELIMITER}${CSV_DELIMITER}/$CSV_DELIMITER $CSV_DELIMITER/g" $TEMP_FILE | column -s "$CSV_DELIMITER" -t
    else
        cp "$CSV_FILE" "$CSV_FILE.bak"
        cp "$TEMP_FILE" "$OUT_CSV"
        sed "s/${CSV_DELIMITER}${CSV_DELIMITER}/$CSV_DELIMITER $CSV_DELIMITER/g;s/${CSV_DELIMITER}${CSV_DELIMITER}/$CSV_DELIMITER $CSV_DELIMITER/g" $OUT_CSV | column -s "$CSV_DELIMITER" -t
    fi

# --- remove command ---
elif [[ $COMMAND == "rem"* ]]; then

    if [[ -z $OPT1 ]]; then
        print_help "ERROR: 3rd parameter needs to be the column index as integer number or the column title!"
        exit 1
    fi

    if [[ "$OPT1" =~ $REGEX_DIGITS ]]; then COLUMN=$OPT1; else COLUMN=$(get_column_index "$CSV_FILE" "$OPT1"); fi
    COLUMN_BEFORE=$((COLUMN - 1))
    COLUMN_AFTER=$((COLUMN + 1))
    while read -r LINE; do
        IFS=$CSV_DELIMITER read -r -a CSV <<< "$LINE"

        LINE=""
        if [[ $COLUMN_BEFORE -ge 0 ]]; then
            for ((i=0;i<=$COLUMN_BEFORE;i++)); do
                LINE+="${CSV[$i]}${CSV_DELIMITER}"
            done
        fi

        if [[ $COLUMN_AFTER -lt ${#CSV[@]} ]]; then
            for ((i=$COLUMN_AFTER;i<${#CSV[@]};i++)); do
                LINE+="${CSV[$i]}${CSV_DELIMITER}"
            done
        fi

        echo "$LINE" | rev | cut -c 2- | rev >> "$TEMP_FILE"
    done < "$CSV_FILE"

    if [[ -n $SIMULATE ]]; then
        sed "s/${CSV_DELIMITER}${CSV_DELIMITER}/$CSV_DELIMITER $CSV_DELIMITER/g;s/${CSV_DELIMITER}${CSV_DELIMITER}/$CSV_DELIMITER $CSV_DELIMITER/g" $TEMP_FILE | column -s "$CSV_DELIMITER" -t
    else
        cp "$CSV_FILE" "$CSV_FILE.bak"
        cp "$TEMP_FILE" "$OUT_CSV"
        sed "s/${CSV_DELIMITER}${CSV_DELIMITER}/$CSV_DELIMITER $CSV_DELIMITER/g;s/${CSV_DELIMITER}${CSV_DELIMITER}/$CSV_DELIMITER $CSV_DELIMITER/g" $OUT_CSV | column -s "$CSV_DELIMITER" -t
    fi

# --- cut command ---
elif [[ $COMMAND == "cut"* ]]; then

    if [[ -z $OPT1 ]]; then
        print_help "ERROR: 3rd parameter needs to be the column index as integer number or the column title!"
        exit 1
    fi

    if [[ "$OPT1" =~ $REGEX_DIGITS ]]; then COLUMN=$OPT1; else COLUMN=$(get_column_index "$CSV_FILE" "$OPT1"); fi
    COLUMN_BEFORE=$((COLUMN - 1))
    while read -r LINE; do
        IFS=$CSV_DELIMITER read -r -a CSV <<< "$LINE"

        LINE=""
        if [[ $COLUMN_BEFORE -ge 0 ]]; then
            for ((i=0;i<=$COLUMN_BEFORE;i++)); do
                LINE+="${CSV[$i]}${CSV_DELIMITER}"
            done
        fi

        echo "$LINE" | rev | cut -c 2- | rev >> "$TEMP_FILE"
    done < "$CSV_FILE"

    if [[ -n $SIMULATE ]]; then
        sed "s/${CSV_DELIMITER}${CSV_DELIMITER}/$CSV_DELIMITER $CSV_DELIMITER/g;s/${CSV_DELIMITER}${CSV_DELIMITER}/$CSV_DELIMITER $CSV_DELIMITER/g" $TEMP_FILE | column -s "$CSV_DELIMITER" -t
    else
        cp "$CSV_FILE" "$CSV_FILE.bak"
        cp "$TEMP_FILE" "$OUT_CSV"
        sed "s/${CSV_DELIMITER}${CSV_DELIMITER}/$CSV_DELIMITER $CSV_DELIMITER/g;s/${CSV_DELIMITER}${CSV_DELIMITER}/$CSV_DELIMITER $CSV_DELIMITER/g" $OUT_CSV | column -s "$CSV_DELIMITER" -t
    fi

# --- move command ---
elif [[ $COMMAND == "mov"* ]]; then

    if [[ -z $OPT1 ]]; then
        print_help "ERROR: 3rd parameter needs to be the column index as integer number or the column title representing the column to be moved!"
        exit 1;
    fi

    if [[ -z $OPT2 ]] || [[ ! "$OPT2" =~ $REGEX_DIGITS ]]; then
        print_help "ERROR: 4th parameter needs to be the column index as integer number representing the column where the moved column should be inserted!"
        exit 1
    fi

    if [[ "$OPT1" =~ $REGEX_DIGITS ]]; then COLUMN_SOURCE=$OPT1; else COLUMN_SOURCE=$(get_column_index "$CSV_FILE" "$OPT1"); fi

    echo "Sorry, feature not implemented yet"

# --- move command ---
elif [[ $COMMAND == "exp"* ]]; then

    if [[ -z $OPT1 ]]; then
        print_help "ERROR: 3rd parameter needs to be the filename under which the column indexes should be stored!"
        exit 1
    fi

    TARGET_FILE=$OPT1

    if [ ! -f "$TARGET_FILE" ]; then
        echo "################################################################################" > "$TARGET_FILE"
        echo "##          This file contains all column indexes of \"$CSV_FILE\"" >> "$TARGET_FILE"
        echo "################################################################################" >> "$TARGET_FILE"

        IFS=$CSV_DELIMITER read -r -a CSV_HEADER <<< "$(head -n 1 $CSV_FILE)"
        for ((i=0;i<${#CSV_HEADER[@]};i++)); do
            echo "COL_${i}=$i # ${CSV_HEADER[$i]}" >> "$TARGET_FILE"
        done
    else
        IFS=$CSV_DELIMITER read -r -a CSV_HEADER <<< "$(head -n 1 $CSV_FILE)"
        for ((i=0;i<${#CSV_HEADER[@]};i++)); do
            FOUND=$(grep -m 1 "# ${CSV_HEADER[$i]}$" "$TARGET_FILE")
            if [[ -n $FOUND ]]; then
                NEW_LINE="${FOUND%%=*}=$i # ${CSV_HEADER[$i]}"
                sed -i -- "s|$FOUND|$NEW_LINE|" "$TARGET_FILE"
            else
                echo "COL_${i}=$i # ${CSV_HEADER[$i]}" >> "$TARGET_FILE"
            fi
        done
    fi

    cat "$TARGET_FILE"

# --- dot_to_comma command ---
elif [[ $COMMAND == "dot_to_comma"* ]]; then
    sed -i -- "s/\./,/g" "$CSV_FILE"

# --- unknown command ---
else
    print_help "ERROR: Unkown command \”$COMMAND\”!"
    exit 1
fi

echo
