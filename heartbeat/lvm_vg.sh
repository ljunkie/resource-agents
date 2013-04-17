#!/bin/bash
#
# Copyright (C) 1997-2003 Sistina Software, Inc.  All rights reserved.
# Copyright (C) 2004-2011 Red Hat, Inc.  All rights reserved.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
#


##
# All volume group variants call into this function for status.
# Some variants (tags) call this function and proceed with some
# other tests as well.
##
function vg_status_normal
{
	local i
	local dev
	local res=$OCF_NOT_RUNNING

	#
	# Check that all LVs are active
	#
	for i in `lvs $OCF_RESKEY_volgrpname --noheadings -o attr`; do
		if [[ ! $i =~ ....a. ]]; then
			return $OCF_NOT_RUNNING
		fi
	done

	#
	# Check if all links/device nodes are present
	#
	for i in `lvs $OCF_RESKEY_volgrpname --noheadings -o name`; do
		dev="/dev/$OCF_RESKEY_volgrpname/$i"

		is_dev_present $dev
		res=$?
		if [ $res -ne $OCF_SUCCESS ]; then
			# err log happens in is_dev_present
			return $res
		fi
	done

	return $res
}

##
# Main status function for volume groups
##
function vg_status
{
	get_vg_mode
	case $? in
	0) vg_status_normal;;
	2) vg_status_normal;; # cluster exclusive is same as normal status.
	*) return $OCF_ERR_UNIMPLEMENTED;;
	esac

	return $?
}

function vg_start_normal
{
	local vgchange_options=$(get_activate_options)
	local res

	ocf_log info "Activating volume group $OCF_RESKEY_volgrpname with options '$vgchange_options'"

	# scan for vg, restore transient failed pvs
	prep_for_activation

	# for clones (clustered volume groups), we'll also have to force
	# monitoring, even if disabled in lvm.conf.
	if ocf_is_clone; then
		vgchange_options="$vgchange_options --monitor y"
	fi

	if ! ocf_run vgchange $vgchange_options $OCF_RESKEY_volgrpname; then
		ocf_log err "Failed to activate volume group, $OCF_RESKEY_volgrpname"
		return $OCF_ERR_GENERIC
	fi

	vg_status_normal
	res=$?
	if [ $res -ne $OCF_SUCCESS ]; then
		ocf_log err "LVM: $OCF_RESKEY_volgrpname did not activate correctly"
		return $res
	fi

	# OK Volume $OCF_RESKEY_volgrpname activated just fine!
	return $OCF_SUCCESS 
}

##
# Main start function for volume groups
##
function vg_start
{
	get_vg_mode
	case $? in
	0) vg_start_normal;;
	2) vg_start_normal;;
	*) return $OCF_ERR_UNIMPLEMENTED;;
	esac

	return $?
}

function vg_stop_normal
{
	vgdisplay "$OCF_RESKEY_volgrpname" 2>&1 | grep 'Volume group .* not found' >/dev/null && {
		ocf_log info "Volume group $OCF_RESKEY_volgrpname not found"
		return $OCF_SUCCESS
	}
	ocf_log info "Deactivating volume group $OCF_RESKEY_volgrpname"
	ocf_run vgchange -aln $OCF_RESKEY_volgrpname || return $OCF_ERR_GENERIC

	vg_status_normal
	# make sure vg isn't still running
	if [ $? -eq $OCF_SUCCESS ]; then
		ocf_log err "LVM: $OCF_RESKEY_volgrpname did not stop correctly"
		return $OCF_ERR_GENERIC 
	fi

	return $OCF_SUCCESS
}

##
# Main stop function for volume groups
##
function vg_stop
{
	get_vg_mode
	case $? in
	0) vg_stop_normal;;
	2) vg_stop_normal;;
	*) return $OCF_ERR_UNIMPLEMENTED;;
	esac

	return $?
}
