#!/bin/bash

#TODO: test --edit option
#TODO: add example usage with preexisting all_samp_100bp_tiles.bed
#TODO: complete documentation of each param

help() {
  cat <<EOF
# basic usage:
# mkdir e.g. dmrs
# make sure you have the cov files you need in a dir for each comparison
# run run.sh with required arguments.
# submit dag

example with custom pipeline: $0 --output-dir ./sadler_ph_dmrs_25p --no-tiles --cov-files-dir ./cov_files/ --samp-ids ph_96h_1-ph_96h_2-ctrl_1-ctrl_2 --treatments 1-1-0-0 --pipeline list\(fraction=FALSE,chr.col=1,start.col=2,end.col=3,coverage.col=4,freqC.col=5,strand.col=NULL\)  --known-genes-file /storage/bfe_reizel/bengst/genomic_reference_data/mm10KnownGenes.bed --meth-difference 25


mandatory arguments:
  --output-dir
  --tiles or --no-tiles
  --cov-files-dir
  --samp-ids
  --treatments
  --pipeline
  --known-genes-file
  --meth-difference

optional arguments:
  #TODO: --edit  run after editing the arguments in dmr_jobs.sub to update heatmap_jobs.sub and homer_jobs.sub to match.


If --no-tiles is given the heatmap script will use all_samps_100bp_tiles_meth_scores.bed produced by methylkit,
this is fine when you use all the samples you want to plot in the heatmap for DMR finding.
Sometimes however it is required to use a subset of samples for DMR finding but plot the methylation values
across other samples as well, in that case use a 100bp tiles file containing all the samples required for plotting
for exmaple the file generated by the rrbs pipeline.

# dmr_jobs args format example:  Young_vs_Old_25p, --meth_call_files_dir ./cov_files --samp_ids Young1-Old1-Young2-Old2 --treatments 1-0-1-0 --pipeline bismarkCoverage --output_dir Young_vs_Old_25p --known_genes_file /storage/bfe_reizel/bengst/genomic_reference_data/mm10KnownGenes.bed --meth_difference 25

# heatmap_jobs.sub args format: \<name_for_condor_logs\>,  \<path to all_samples_100bp_tiles.bed\> \<sample_dir - output dir of dmr_job\> [args for make_heatmap.R]
If all_samples_100bp_tiles.bed include more samples than you want to show in your heatmap you must edit heatmap_jobs.args
use: --sample_names \<ordered names of samples in all_samples_100bp_tiles.bed\> --include_samples_by_name \<samples to inclide\>
e.g. --sample_names 56n-58n-56p-57n-54n-54p-55n --include_samples_by_name 54n-55n-56n-57n

# homer_jobs args sholud only contain the sample dir names, without prefix ./ or trailing /

More than one job can be run by adding argument lines at the end of the corresponding .sub files.
the .sub files do not have to match when you wish to run a different number or combination of jobs at each stage.
Usually the .sub files do match for running a fixed set of jobs through the pipeline. For this purpose you may edit
only dmr_jobs.sub and rerun this script with the --edit flag.

# e.g.
# edit dmr_jobs.args - make the condor name (1st arg) the same as the output_dir (may also work without this but more messy and not well tested)
#   Example dmr_jobs.args :
#     Young_vs_Old_25p, --meth_call_files_dir /storage/bfe_reizel/bengst/analyzed_data/further_look_at_Renegeration_for_ISF_grant/new_dmrs/Young_vs_Old_cov_files --samp_ids Young1-Old1-Young2-Old2 --treatments 1-0-1-0 --pipeline bismarkCoverage --output_dir ./Young_vs_Old_25p/ --known_genes_file /storage/bfe_reizel/bengst/genomic_reference_data/mm10KnownGenes.bed --meth_difference 25
#     Young_vs_YoungYoung_30p, --meth_call_files_dir /storage/bfe_reizel/bengst/analyzed_data/further_look_at_Renegeration_for_ISF_grant/new_dmrs/Young_vs_YoungYoung_cov_files --samp_ids YoungYoung1-YoungYoung2-Young1-Young2 --treatments 0-0-1-1 --pipeline bismarkCoverage --output_dir ./Young_vs_YoungYoung_30p/ --known_genes_file /storage/bfe_reizel/bengst/genomic_reference_data/mm10KnownGenes.bed --meth_difference 30
# run run.sh 2nd time
# submit

EOF
}

main() {
  REPO_FOR_REIZEL_LAB=/storage/bfe_reizel/bengst/repo_for_reizel_lab

  arg_parse "$@"
  write_dmr_jobs_sub_file
  write_heatmap_jobs_sub_file
  write_homer_jobs_sub_file
  write_condor_dag
  make_dirs

  echo Submit the jobs by running: condor_submit_dag dmr_pipline_jobs.dag
  echo Good Luck!
}

write_dmr_jobs_sub_file() {
  cat <<EOF >dmr_jobs.sub
environment = REPO_FOR_REIZEL_LAB=$REPO_FOR_REIZEL_LAB
executable = $REPO_FOR_REIZEL_LAB/run_on_atlas/dmrs_condor_dag/dmr_job.sh
log = ./\$(name)/condor_logs/dmrs_\$(name).log
output = ./\$(name)/condor_logs/dmrs_\$(name).out
error = ./\$(name)/condor_logs/dmrs_\$(name).out
request_cpus = 1
Initialdir = $(pwd)
Arguments = \$(args)
RequestMemory = 8GB
universe = vanilla
queue name,args from (
$(echo $output_dir | awk -F / '{printf $NF}'), \
 --meth_call_files_dir $cov_files_dir \
 --samp_ids $samp_ids \
 --treatments $treatments \
 --pipeline $pipeline \
 --output_dir $output_dir \
 --known_genes_file $known_genes_file \
 --meth_difference $meth_difference
)
EOF
}

write_heatmap_jobs_sub_file() {
  cat <<EOF >heatmap_jobs.sub
environment = REPO_FOR_REIZEL_LAB=$REPO_FOR_REIZEL_LAB
executable = $REPO_FOR_REIZEL_LAB/run_on_atlas/dmrs_condor_dag/heatmap_job.sh
log = ./\$(name)/condor_logs/heatmap_\$(name).log
output = ./\$(name)/condor_logs/heatmap_\$(name).out
error = ./\$(name)/condor_logs/heatmap_\$(name).out
request_cpus = 1
Initialdir = $(pwd)
Arguments = \$(args)
RequestMemory = 1GB
universe = vanilla
queue name,args from (
$(echo $output_dir | awk -F / '{printf $NF}'), \
$all_samples_100bp_tiles \
$output_dir \
--sample_names $samp_ids
)
EOF
}

write_homer_jobs_sub_file() {
  cat <<EOF >homer_jobs.sub
environment = REPO_FOR_REIZEL_LAB=$REPO_FOR_REIZEL_LAB
executable = $REPO_FOR_REIZEL_LAB/run_on_atlas/dmrs_condor_dag/homer_job.sh
log = ./\$(name)/condor_logs/homer_\$(name).log
output = ./\$(name)/condor_logs/homer_\$(name).out
error = ./\$(name)/condor_logs/homer_\$(name).out
request_cpus = 10
Initialdir = $(pwd)
Arguments = \$(name)
RequestMemory = 4GB
universe = vanilla
queue name from (
$(echo $output_dir | awk -F / '{printf $NF}' | sed -E 's/\.\/|\/$//g')
)
EOF
}

write_condor_dag() {
  cat <<EOF >dmr_pipline_jobs.dag
JOB find_dmrs dmr_jobs.sub
JOB heatmap heatmap_jobs.sub
JOB homer  homer_jobs.sub

PARENT find_dmrs  CHILD heatmap homer
EOF
}

make_dirs() {
  awk -F , '{if ($0==")") next; if (start) print "mkdir -p "$1"/condor_logs"} {if ($0=="queue name,args from (")  start=1;}' dmr_jobs.sub | bash
}

edit() {

  #delete previous args
  cat heatmap_jobs.sub | awk '{if ($0==")") start=0; if (!start) print $0} {if ($0=="queue name,args from (")  start=1;}' >temp
  cat temp | awk -v heatmap_args="$heatmap_args" '{if ($0=="queue name,args from (") {print $0; print heatmap_args} else {print $0}}'
  rm temp

  #heatmap args
  heatmap_args=$(
    cat dmr_jobs.sub |
      awk '{if ($0==")") next; if (start) print $0} {if ($0=="queue name,args from (")  start=1;}' |
      awk -F , -v all_samp_tiles=$all_samples_100bp_tiles 'match($0, /--samp_ids ([^ ]*)/, array)  match($0, /--output_dir ([^ ]*)/, array2) {print $1",",  all_samp_tiles, array2[1], "--sample_names " array[1]}'
  )
  #delete previous args
  cat heatmap_jobs.sub | awk '{if ($0==")") start=0; if (!start) print $0} {if ($0=="queue name,args from (")  start=1;}' >temp
  #write new args
  cat temp | awk -v heatmap_args="$heatmap_args" '{if ($0=="queue name,args from (") {print $0; print heatmap_args} else {print $0}}' >heatmap_jobs.sub
  rm temp

  #homer args
  homer_args=$(
    cat dmr_jobs.sub |
      awk '{if ($0==")") next; if (start) print $0} {if ($0=="queue name,args from (")  start=1;}' |
      awk -F , 'match($0, /--output_dir ([^ ]*)/, array2){print array2[1]}' | sed -E 's/\.\/|\/$//g'
  )
  #delete previous args
  cat homer_jobs.sub | awk '{if ($0==")") start=0; if (!start) print $0} {if ($0=="queue name from (")  start=1;}' >temp
  cat temp | awk -v homer_args="$homer_args" '{if ($0=="queue name from (") {print $0; print homer_args} else {print $0}}' >homer_jobs.sub
  rm temp

}

arg_parse() {
  if [[ $# -eq 0 ]]; then
    help
    exit 1
  fi

  while [[ $# -gt 0 ]]; do
    case $1 in
    -h | --help)
      help
      exit 1
      ;;
    --output-dir)
      output_dir="$2"
      shift # past argument
      shift # past value
      ;;
    --no-tiles)
      no_tiles=1
      all_samples_100bp_tiles="${output_dir}/all_samps_100bp_tiles_meth_scores.bed"
      echo no tiles provided, the heatmap script will use all_samps_100bp_tiles_meth_scores.bed produced by methylkit.
      echo see help for details
      shift # past argument
      ;;
    --tiles)
      no_tiles=0
      if [[ ! $(echo $1 | grep "\.bed") ]]; then
        echo expecting bed file after --tiles, got $2
        help
        exit 1
      else
        all_samples_100bp_tiles=$1
      fi
      ;;
    --cov-files-dir)
      cov_files_dir=$2
      shift
      shift
      ;;
    --samp-ids)
      samp_ids=$2
      shift
      shift
      ;;
    --treatments)
      treatments=$2
      shift
      shift
      ;;
    --pipeline)
      pipeline=$2
      shift
      shift
      ;;
    --known-genes-file)
      known_genes_file=$2
      shift
      shift
      ;;
    --meth-difference)
      meth_difference=$2
      shift
      shift
      ;;
    --edit)
      edit
      exit 0
      ;;
    *)
      help
      exit 1
      ;;
    esac
  done

  [[ -z $output_dir ]] && echo missing argument --output-dir && exit 1
  [[ -z $no_tiles ]] && echo missing argument --tiles or --no-tiles && exit 1
  [[ -z $cov_files_dir ]] && echo missing argument --cov-files-dir && exit 1
  [[ -z $samp_ids ]] && echo missing argument --samp-ids && exit 1
  [[ -z $treatments ]] && echo missing argument --treatments && exit 1
  [[ -z $pipeline ]] && echo missing argument --pipeline && exit 1
  [[ -z $known_genes_file ]] && echo missing argument --known-genes-file && exit 1
  [[ -z $meth_difference ]] && echo missing argument --meth-difference && exit 1
}

main "$@"
