#!/bin/bash
page_dir="pages"
converter_dir="converters"
target_dir="target"

source_ext="md"
target_ext="html"

page_files=()
converters_count=0
processed_count=0
copied_count=0

function scan_page_dir { # recursively scan $1 directory, put file names to $page_files
	for page_file in "$1"/*
	do
		if [[ -f "$page_file" ]]
		then
			page_files+=("$page_file")
		elif [[ -d "$page_file" ]]
		then
			scan_page_dir "$page_file"
		fi
	done
}

function scan_pages { # recursively scan pages directory, put file names to $page_files
	scan_page_dir "$page_dir"
}

function scan_converters { # non-recursively scan converters directory, execute found scripts, rename each "convert" function to "converter*_convert", update $converters_count
	for converter_file in "$converter_dir"/*
	do
		if [[ -f "$converter_file" ]]
		then
			unset -f convert
			source "$converter_file"
			if [[ $(type -t convert) == function ]]
			then
				eval "converter${converters_count}_$(declare -f convert)" # add prefix to function name
				let converters_count+=1
			else
				echo "warning: $converter_file: no convert function"
			fi
		fi
	done
	unset -f convert
}

function process_converters { # execute all converters for $1 line, put result to $result
	result="$1"
	local i;
	for (( i=0; i<converters_count; i++))
	do
		"converter${i}_convert" "$result"
	done
}

function process_page { # read all lines from $1 file, execute all converters for each line, put result lines to $2 file
	local input="$1"
	local output="$2"
	mkdir -p "${output%/*}"
	while read -r line || [[ -n "$line" ]]
	do
		line="${line//$'\r'}" # remove CR
		process_converters "$line"
		echo "$result"
	done < "$input" > "$output"
}

function process_resource { # copy file from $1 to $2
	local input="$1"
	local output="$2"
	mkdir -p "${output%/*}"
	cp "$input" "$output"
}

function process_pages { # process all pages, put results to target directory
	local input
	local output
	local filename
	local extension
	for input in "${page_files[@]}"
	do
		output="$input"
		[[ "${output:0:$((${#page_dir}+1))}" == "$page_dir/" ]] && output="${output:$((${#page_dir}+1))}" # remove top-level directory
		output="$target_dir/$output"

		filename="${input##*/}" # get filename without path
		extension="${filename##*.}" # get extension or filename if no extension
		if [[ "$filename" != "$extension" && "$extension" = "$source_ext" ]]
		then
			output="${output:0:$((${#output}-${#source_ext}))}$target_ext" # change extension
			process_page "$input" "$output"
			let processed_count++
		else
			process_resource "$input" "$output"
			let copied_count++
		fi
	done
}

scan_pages
scan_converters
process_pages
echo "processed $processed_count pages with $converters_count converters, copied $copied_count resource files"
