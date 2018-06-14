#!/bin/bash
options=`getopt -o i:o:t:b:a:f:d:rkhz -l input:,output:,atlas-head:,atlas-brain:,folder:,keep-files,refine,dof:,file-dictionary,help -n 'antsSkullStrip.sh' -- "$@"`
eval set -- "$options"

function display_help() {
    echo "Usage: `basename $0` -i <input head> -t <atlas head> -b <atlas brain>"
    echo "script to mask a subject using ANTs and an example or atlas masked subject."
    echo "Outputs are suffixed with _brain"
    echo "	Required:"
    echo "	-i|--input <input img>        input subject head to be masked"
    echo "	-t|--atlas-head <ref img>     reference head"
    echo "	-b|--atlas-brain <ref img>    reference brain.  Can be a mask if not using refine option."
    echo "	Optional:"
    echo "	-o|--output <output prefix>   optional output prefix. Default is input."
    echo "	-f|--folder <output folder>   working directory.  Defaults to cwd"
    echo "	-r|--refine                   refine atlas to subject warp"
    echo "	-d|--dof <degrees=6>          degrees of freedom for initial linear transform."
    echo "	-k|--keep-files               keeps transitionary warps and transforms"
    echo "	-z|--file-dictionary          display file dictionary"
    echo "	-h|--help                     show usage/commands"
    exit $1
}

function display_file_dictionary() {
	echo "atlh_lin2_input.nii.gz:        atlas head linearly registered to input"
	echo "atlh2input(.mat|Flirt.txt):    associated linear transformation matrix"
	echo "atlb_warp2_input:              atlas brain nonlinearly warped to input"
	echo "atlh2inputWarp.nii.gz:         associated warpfield"
	echo "atlh2inputAffine.txt:          affine refinement prior to nonlinear warp"
	echo ""
	echo "atlb... :                      if refine option is chosen, these are"
	echo "                               refined transforms using atlas brain to"
	echo "                               input brain."
	exit
}

echo "`basename $0` $options"
# extract options and their arguments into variables.
while true ; do
	case "$1" in
		-i|--input)
			input="$2"
			shift 2
			;;
		-o|--output)
			output="$2"
			shift 2
			;;
		-t|--atlas-head)
			atl_head="$2"
			shift 2
			;;
		-b|--atlas-brain)
			atl_brain="$2"
			shift 2
			;;
		-f|--folder)
			folder="$2"
			shift 2
			;;
		-r|--refine)
			refine=1
			shift 1
			;;
		-k|--keep-files)
			keep=1
			shift 1
			;;
		-d|--dof)
			dof="-dof $2"
			shift 2
			;;
			-z|--file-dictionary)
			display_file_dictionary
			;;
		-h|--help)
			display_help
			;;
		--) shift; break
			;;
		*) echo "Unexpected error parsing args!" ; display_help 1 ;;
	esac
done
if [ -z $input ] || [ -z $atl_head ] || [ -z $atl_brain ]; then display_help 1; fi
if [ ! $(command -v ${ANTSPATH}${ANTSPATH:+/}ANTS) ]; then
	echo ${ANTSPATH}${ANTSPATH:+/}ANTS not found!
	exit 1
fi
if [ ! $(command -v ${C3DPATH}${C3DPATH:+/}c3d_affine_tool) ]; then
	echo -e "c3d_affine_tool path not found!"
	exit 1
fi

# check validity of inputs, set defaults
if [ -e $input ]; then
	input=$(remove_ext $input)
else
	echo "Input not found" 1&>2
	display_help 1
fi
if [ ! -e $atl_head ] || [ ! -e $atl_brain ]; then
	echo "Atlas not found!" 1&>2
	display_help 1
fi
if [ -z $dof ]; then dof="-dof 6"; fi
if [ -z $output ]; then output=$(remove_ext $input)_brain; fi
output=$(remove_ext ${output})
refine=${refine:-0}
keep=${keep:-0}
pushd ${folder:-$PWD} > /dev/null

#  intial affine registration
echo "performing initial affine registration"
${FSLDIR}/bin/flirt -v $dof -in "$atl_head" -ref "$input" -out atlh_lin2_input -omat atlh2input.mat -interp spline
${C3DPATH}${C3DPATH:+/}c3d_affine_tool -ref "$input" -src "$atl_head" atlh2input.mat -fsl2ras -oitk atlh2inputFlirt.txt

#  nonlinear warp to target
echo "caculating warp from atlas head to input"
${ANTSPATH}${ANTSPATH:+/}ANTS 3 -m CC["$input",atlh_lin2_input.nii.gz,1,5] -t SyN[0.25] \
	-r Gauss[3,0] -o atlh2input -i 60x50x20 --use-Histogram-Matching  \
	--number-of-affine-iterations 10000x10000x10000x10000x10000 \
	--MI-option 32x16000
${ANTSPATH}${ANTSPATH:+/}antsApplyTransforms -d 3 -i "$atl_brain" -o atlb_warp2_input.nii.gz \
	-r "$input".nii.gz -n NearestNeighbor -t atlh2inputWarp.nii.gz atlh2inputAffine.txt atlh2inputFlirt.txt #  Perhaps use NN?

${FSLDIR}/bin/fslmaths atlb_warp2_input -bin atlb_warp2_input_mask
${FSLDIR}/bin/fslmaths "$input" -mas atlb_warp2_input_mask "$output"

if (($refine)); then
	echo "refining inital affine registration using masked image"
	mv "$output".nii.gz "$output"_unrefined.nii.gz
	${FSLDIR}/bin/flirt -v -in "$atl_brain" -ref "$output"_unrefined.nii.gz -out atlb_lin2_input -omat atlb2input.mat -interp spline
	${C3DPATH}${C3DPATH:+/}c3d_affine_tool -ref "$output"_unrefined.nii.gz -src "$atl_brain" atlb2input.mat -fsl2ras -oitk atlb2inputFlirt.txt
	
	echo "refining nonlinear warp using masked image"
	${ANTSPATH}${ANTSPATH:+/}ANTS 3 -m CC["$output"_unrefined.nii.gz,atlb_lin2_input.nii.gz,1,5] -t SyN[0.25] \
		-r Gauss[3,0] -o atlb2input -i 60x50x20 --use-Histogram-Matching  \
		--number-of-affine-iterations 10000x10000x10000x10000x10000 \
		--MI-option 32x16000
	${ANTSPATH}${ANTSPATH:+/}antsApplyTransforms -d 3 -i "$atl_brain" -o atlb_warp2_input.nii.gz \
		-r "$output"_unrefined.nii.gz -n NearestNeighbor -t atlb2inputWarp.nii.gz atlb2inputAffine.txt atlb2inputFlirt.txt #  Perhaps use NN?
	
	${FSLDIR}/bin/fslmaths atlb_warp2_input -bin atlb_warp2_input_mask
	${FSLDIR}/bin/fslmaths "$input" -mas atlb_warp2_input_mask "$output"
fi

if (($keep)); then
	set -e
	mkdir skull_strip_xfms
	mv atl?2inputWarp.nii.gz atl?2inputInverseWarp.nii.gz atl?2inputAffine.txt atl?2inputFlirt.txt atl?2input.mat skull_strip_xfms/
else
	rm atl?2inputWarp.nii.gz atl?2inputInverseWarp.nii.gz atl?2inputAffine.txt atl?2inputFlirt.txt atl?2input.mat \
		atl?_lin2_input.nii.gz atl?_warp2_input.nii.gz atl?_warp2_input_mask.nii.gz
fi

echo "finished `basename $0`"
