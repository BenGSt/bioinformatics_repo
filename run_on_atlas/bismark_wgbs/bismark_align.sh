#!/bin/bash

N_CORES=5
MEM=40GB
N_PARALLEL_INSTANCES=1 #manual states ~5 cores per instance, But i'm seeing more on htcondor logs.
                        # Also exceeding MEM too often. changing to 1 parallel instance. 14.03.2023



help()
{
	cat << EOF
	run after trim_illumina_adaptors.sh
		resources: $N_CORES cores, $MEM RAM

	<-single-end> or <-paired-end>
	<-output-dir>
	-genome <mm10 or hg38>
	[-non-directional]   instructs Bismark to use all four alignment outputs (OT, CTOT, OB, CTOB)
EOF
}


main()
{
  source /Local/bfe_reizel/anaconda3/bin/activate wgbs_bismark_pipeline_2023
  arg_parse "$@"
	cd "$output_dir" || exit 1
	script_name=$(echo $0 | awk -F / '{print $NF}')

	echo
	echo
	echo \#################################
	echo \#################################
	echo running: $script_name "$@"
	echo date: $(date)
	echo hostname: $(hostname)
	echo pwd: $(pwd)
	echo \#################################
	echo \#################################
	echo
	echo

	if [[ $genome == "mm10" ]]; then
	  bismark_genome_location=/storage/bfe_reizel/bengst/genomic_reference_data/from_huji/mm10/Sequence/WholeGenomeFasta
	elif [[ $genome == "hg38" ]]; then
	  bismark_genome_location=/srv01/technion/bengst/storage/genomic_reference_data/hg38/minChromSet/hg38.minChromSet.chroms
	  # NOTE: deleted all random and unknown chromosomes from hg38 analysis set to reduce memory usage, s.t.
	  #       bismark can run on atlas, which is restricted to 40GB per job.
	else
	  echo genome not recognized
	  exit 1
  fi

	align_to_genome

  #cleanup
  rm_fq="rm -v *.fq" #the non gz trimmed fq
  if [[ $keep_trimmed_fq -eq 0 ]]; then #TODO: add this to args
    $rm_fq
  fi
  rm -v *.fq.gz #rm unmapped, ambiguous

	echo
	echo
	echo \#################################
	echo \#################################
	echo finished: $script_name "$@"
	echo date: $(date)
	echo hostname: $(hostname)
	echo pwd: $(pwd)
	echo \#################################
	echo \#################################
	echo
	echo
}


align_to_genome()
{
  #see http://felixkrueger.github.io/Bismark/Docs/ :
    #"--parallel 4 for e.g. the GRCm38 mouse genome will probably use ~20 cores and eat ~48GB of RAM,
    # but at the same time reduce the alignment time to ~25-30%. You have been warned."
  # Atlas max cpu request is 10 so I want to have 2 instances of bismark (5 cores each theoretically)
  # This is set in align_jobs.sub .

  #fixes Bad file descriptor error (Seems like a bug), and reduces memory usage.
  unmapped_ambig="--un --ambiguous"


  if [[ $read_type == "single_end" ]] ; then
    trim_galore_output=$(find . -name '*trimmed.fq*')
    command=$(echo bismark --multicore $N_PARALLEL_INSTANCES --bowtie2 $dovetail --genome $bismark_genome_location $trim_galore_output $non_directional $unmapped_ambig)
	else
	  trim_galore_output_1=$(find . -name '*val_1.fq*')
	  trim_galore_output_2=$(find . -name '*val_2.fq*')
    command=$(echo bismark --multicore $N_PARALLEL_INSTANCES --bowtie2 $dovetail --genome $bismark_genome_location -1 $trim_galore_output_1 -2 $trim_galore_output_2 $non_directional $unmapped_ambig)
	fi

  echo runnig: $command
  $command
}



arg_parse()
{
  while [[ $# -gt 0 ]]; do
    case $1 in
      -single-end)
        read_type="single_end"
        shift
        ;;
      -paired-end)
        read_type="paired_end"
        shift
        ;;
      -output-dir)
        output_dir="$2"
        shift
        shift
        ;;
      -non-directional)
        non_directional="--non_directional"
        shift
        ;;
      -dovetail)
        dovetail="--dovetail"
        shift
        ;;
      -genome)
        genome=$2
        shift
        shift
        ;;
        -*|--*)
        help
        exit 1
        ;;
        -h|--help)
        help
        exit 1
        ;;
    esac
done
}


main "$@"