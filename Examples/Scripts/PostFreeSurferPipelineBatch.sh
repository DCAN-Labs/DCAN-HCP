#!/bin/bash 

get_batch_options() {
    local arguments=("$@")

    unset command_line_specified_study_folder
    unset command_line_specified_subj
    unset command_line_specified_run_local

    local index=0
    local numArgs=${#arguments[@]}
    local argument

    while [ ${index} -lt ${numArgs} ]; do
        argument=${arguments[index]}

        case ${argument} in
            --StudyFolder=*)
                command_line_specified_study_folder=${argument#*=}
                index=$(( index + 1 ))
                ;;
            --Subject=*)
                command_line_specified_subj=${argument#*=}
                index=$(( index + 1 ))
                ;;
            --runlocal)
                command_line_specified_run_local="TRUE"
                index=$(( index + 1 ))
                ;;
	    *)
		echo ""
		echo "ERROR: Unrecognized Option: ${argument}"
		echo ""
		exit 1
		;;
        esac
    done
}

get_batch_options "$@"

StudyFolder="${HOME}/projects/Pipelines_ExampleData" #Location of Subject folders (named by subjectID)
Subjlist="100307" #Space delimited list of subject IDs
EnvironmentScript="${HOME}/projects/Pipelines/Examples/Scripts/SetUpHCPPipeline.sh" #Pipeline environment script

if [ -n "${command_line_specified_study_folder}" ]; then
    StudyFolder="${command_line_specified_study_folder}"
fi

if [ -n "${command_line_specified_subj}" ]; then
    Subjlist="${command_line_specified_subj}"
fi

# Requirements for this script
#  installed versions of: FSL (version 5.0.6), FreeSurfer (version 5.3.0-HCP), gradunwarp (HCP version 1.0.2)
#  environment: FSLDIR , FREESURFER_HOME , HCPPIPEDIR , CARET7DIR , PATH (for gradient_unwarp.py)

#Set up pipeline environment variables and software
source ${EnvironmentScript}

# Log the originating call
echo "$@"

#if [ X$SGE_ROOT != X ] ; then
#    QUEUE="-q long.q"
    QUEUE="-q hcp_priority.q"
#fi

PRINTCOM=""
#PRINTCOM="echo"
#QUEUE="-q veryshort.q"


########################################## INPUTS ########################################## 

#Scripts called by this script do assume they run on the outputs of the FreeSurfer Pipeline

######################################### DO WORK ##########################################

useT2=${useT2:-true} # sets the useT2 flag default to "true" - AP 20162111
for Subject in $Subjlist ; do
  echo $Subject

  #Input Variables
  SurfaceAtlasDIR="${HCPPIPEDIR_Templates}/standard_mesh_atlases"
  GrayordinatesSpaceDIR="${HCPPIPEDIR_Templates}/91282_Greyordinates"
  GrayordinatesResolutions="2" #Usually 2mm, if multiple delimit with @, must already exist in templates dir
  HighResMesh="164" #Usually 164k vertices
  LowResMeshes="32" #Usually 32k vertices, if multiple delimit with @, must already exist in templates dir
  SubcorticalGrayLabels="${HCPPIPEDIR_Config}/FreeSurferSubcorticalLabelTableLut.txt"
  FreeSurferLabels="${HCPPIPEDIR_Config}/FreeSurferAllLut.txt"
  ReferenceMyelinMaps="${HCPPIPEDIR_Templates}/standard_mesh_atlases/Conte69.MyelinMap_BC.164k_fs_LR.dscalar.nii"
  # RegName="MSMSulc" #MSMSulc is recommended, if binary is not available use FS (FreeSurfer)
  RegName="FS" 
  
  ## Variables for ANTs based Atlas Registration
  T1wTemplate="${HCPPIPEDIR_Templates}/MNI152_T1_1mm.nii.gz"
  T1wTemplateBrain="${HCPPIPEDIR_Templates}/MNI152_T1_1mm_brain.nii.gz"
  T1wTemplate2mm="${HCPPIPEDIR_Templates}/MNI152_T1_2mm.nii.gz"
  T1wTemplate2mmBrain="${HCPPIPEDIR_Templates}/MNI152_T1_2mm_brain.nii.gz"
  T2wTemplate="${HCPPIPEDIR_Templates}/MNI152_T2_1mm.nii.gz"
  T2wTemplateBrain="${HCPPIPEDIR_Templates}/MNI152_T2_1mm_brain.nii.gz"
  T2wTemplate2mm="${HCPPIPEDIR_Templates}/MNI152_T2_2mm.nii.gz"
  TemplateMask="${HCPPIPEDIR_Templates}/MNI152_T1_1mm_brain_mask.nii.gz"
  Template2mmMask="${HCPPIPEDIR_Templates}/MNI152_T1_2mm_brain_mask_dil.nii.gz"
  FNIRTConfig="${HCPPIPEDIR_Config}/T1_2_MNI152_2mm.cnf"

  if [ -n "${command_line_specified_run_local}" ] ; then
      echo "About to run ${HCPPIPEDIR}/PostFreeSurfer/PostFreeSurferPipeline.sh"
      queuing_command=""
  else
      echo "About to use fsl_sub to queue or run ${HCPPIPEDIR}/PostFreeSurfer/PostFreeSurferPipeline.sh"
      queuing_command="${FSLDIR}/bin/fsl_sub ${QUEUE}"
  fi

  ${queuing_command} ${HCPPIPEDIR}/PostFreeSurfer/PostFreeSurferPipeline.sh \
      --path="$StudyFolder" \
      --subject="$Subject" \
      --surfatlasdir="$SurfaceAtlasDIR" \
      --grayordinatesdir="$GrayordinatesSpaceDIR" \
      --grayordinatesres="$GrayordinatesResolutions" \
      --hiresmesh="$HighResMesh" \
      --lowresmesh="$LowResMeshes" \
      --subcortgraylabels="$SubcorticalGrayLabels" \
      --freesurferlabels="$FreeSurferLabels" \
      --refmyelinmaps="$ReferenceMyelinMaps" \
      --regname="$RegName" \
      --useT2="$useT2" \
      --useAntsReg="$useAntsReg" \
      --useStudyTemplate="$useStudyTemplate" \
      --studytemplate="$StudyTemplate" \
      --studytemplatebrain="$StudyTemplateBrain" \
      --t1template="$T1wTemplate" \
      --t1templatebrain="$T1wTemplateBrain" \
      --t1template2mm="$T1wTemplate2mm" \
      --t1template2mmbrain="$T1wTemplate2mmBrain" \
      --t2template="$T2wTemplate" \
      --t2templatebrain="$T2wTemplateBrain" \
      --t2template2mm="$T2wTemplate2mm" \
      --templatemask="$TemplateMask" \
      --template2mmmask="$Template2mmMask" \
      --config="$FNIRTConfig" \
      --printcom=$PRINTCOM

  # The following lines are used for interactive debugging to set the positional parameters: $1 $2 $3 ...
  
   echo "set -- --path="$StudyFolder" \
      --subject="$Subject" \
      --surfatlasdir="$SurfaceAtlasDIR" \
      --grayordinatesdir="$GrayordinatesSpaceDIR" \
      --grayordinatesres="$GrayordinatesResolutions" \
      --hiresmesh="$HighResMesh" \
      --lowresmesh="$LowResMeshes" \
      --subcortgraylabels="$SubcorticalGrayLabels" \
      --freesurferlabels="$FreeSurferLabels" \
      --refmyelinmaps="$ReferenceMyelinMaps" \
      --regname="$RegName" \
      --useT2="$useT2" \
      --useAntsReg="$useAntsReg" \
      --useStudyTemplate="$useStudyTemplate" \
      --studytemplate="$StudyTemplate" \
      --studytemplatebrain="$StudyTemplateBrain" \
      --t1template="$T1wTemplate" \
      --t1templatebrain="$T1wTemplateBrain" \
      --t1template2mm="$T1wTemplate2mm" \
      --t1template2mmbrain="$T1wTemplate2mmBrain" \
      --t2template="$T2wTemplate" \
      --t2templatebrain="$T2wTemplateBrain" \
      --t2template2mm="$T2wTemplate2mm" \
      --config="$FNIRTConfig" \
      --printcom=$PRINTCOM"
      
   echo ". ${EnvironmentScript}"
done

