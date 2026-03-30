#!/usr/bin/env bash
#kubectl use context

declare config_dir="$HOME/.kube/config.d"
declare latest_file="$HOME/.kube/kuc_latest"
declare local_bin="$HOME/.local/bin"
declare current_shell=${SHELL##*/}

install_self() {
	mkdir -p $local_bin
	self=$(readlink -f "$0")
	cp $self $local_bin/
	echo "Copied $self to $local_bin/$(basename $self)"
	sed -i '/^#kubectl use context/d' $HOME/.${current_shell}rc
	sed -i '/^kuc().*/d' $HOME/.${current_shell}rc
	echo "#kubectl use context
kuc() { source $local_bin/$(basename $self) \"\$@\"; }" >> $HOME/.${current_shell}rc
}

import() {
	local -a config_files=("$@")
	if [ "${#config_files[@]}" -eq 0 ]; then
		echo "Empty input. Exiting..."
	else
		for config_file in "${config_files[@]}"; do
			if ! [ -f "$config_file" ]; then
				echo "$config_file doesn't exist skipping..."
				continue
			else
				file_name=$(basename $config_file)
				cp $config_file $config_dir/$file_name
				chmod 600 $config_dir/$file_name
				echo "copied $config_file to $config_dir/$file_name"
			fi
		done
	fi
}

current() {
	if [ -z ${KUBECONFIG+true} ]; then
		echo "No config file is being used at the moment..."
	else
		local current=$KUBECONFIG
		echo "$current"
	fi
}

latest() {
	if ! [ -f $latest_file ] || [ "$(cat $latest_file)" = "none" ]; then
		echo "No config is being used at the moment..."
	else
		local latest=$(cat $latest_file)
		echo "$latest"
	fi
}

none() {
	if [ -z ${KUBECONFIG+true} ]; then
		echo "No config file is being used at the moment..."
	else
		unset KUBECONFIG
		sed -i '/^#kubectl context config file/d' $HOME/.${current_shell}rc
		sed -i '/^.*KUBECONFIG.*/d' $HOME/.${current_shell}rc
		echo "none" > $latest_file
  fi
}

help() {
	echo "Kubectl Use Context Script"
	echo "Usage:
	./kuc.sh --help -> show this page
	./kuc.sh install -> copy the script to $local_bin
	kuc import [config files] -> copy the config files to $config_dir
	kuc latest -> print the latest config in use (this will load on new session)
	kuc current -> print the current config in use (active in current session)
	kuc -> select configs interactively
	kuc [number] -> select a specific config
	kuc none -> don't use any kubectl config for current next session"
}

update_kubeconfig() {
	local context_to_use="$1"
	local latest_config=$(ls ${config_dir} | grep -e "^.*${context_to_use}.[yaml|yml].*$")
	echo "Using config file $config_dir/$latest_config"

	export KUBECONFIG="${config_dir}/${latest_config}"

	sed -i '/^#kubectl context config file/d' $HOME/.${current_shell}rc
	sed -i '/^.*KUBECONFIG.*/d' $HOME/.${current_shell}rc

	echo "#kubectl context config file
export KUBECONFIG=${config_dir}/${latest_config}" >> $HOME/.${current_shell}rc
	
	local latest_config=$(ls $config_dir | grep $context_to_use)
	echo "$config_dir/$latest_config" > $latest_file
}

select_config() {
	local -a contexts=($(ls $config_dir | sed 's/.yaml//' | sed s'/.yml//'))
	if ! [ "$#" -eq 0 ] && [[ "$1" =~ ^([0-9]{1,3})$ ]] && [[ "$1" -gt 0 ]] && [[ "$1" -le ${#contexts[@]} ]]; then
		local option="$1"
	else
		echo "No args given. Going into interactive mode..."
		while true; do
			echo "Choose a context to use..."
			i=1
			for context in ${contexts[@]}; do
				echo "#$i -> $context"
				i=$(($i+1))
			done

			read -p "#? -> " option

			if [[ "$option" -gt 0 ]] && [[ "$option" =~ ^([0-9]{1,3})$ ]] && [[ "$option" -le ${#contexts[@]} ]]; then
				break
			else
				echo "Invalid input. Please enter numbers between 1 and ${#contexts[@]}..."
			fi
		done
	fi
	option=$(($option-1))
	local context_to_use="${contexts[$option]}"
	
	update_kubeconfig "$context_to_use"
}

kuc_main(){
	local option="$1" 
	shift

	if ! [ -d "$config_dir" ]; then
		echo "$config_dir doesn't exist yet, creating..."
		mkdir -m 750 -p $config_dir
	fi

	case $option in
		"--help")
			help
			;;
		"current")
			current
			;;
		"latest")
			latest
			;;
		"install")
			install_self
			;;
		"import")
			import "$@"
			;;
		[0-9]|[0-9][0-9]|[0-9][0-9][0-9]|"")
			select_config "$option"
			;;
		"none")
			none
			;;
		*)
			echo "Unknown option $option..."
			;;
	esac
}

kuc_main "$@"
