#!/bin/bash

# This script runs on ProNET AV server, looking only for files on the AV server's built-in storage
# It is used by the dataflow management software written by ProNET IT team
# That pipeline runs regularly on AV server via cron job from root account
# It works with the completed_audio files produced by daily_journal_dataflow_qc code

### SERVER SPECIFIC COMPONENTS

# hard coded settings for Pronet specifically, used within below code
smile_execute_root=/opt/software/opensmile/build/progsrc/smilextract
smile_config_root=/opt/software/opensmile/config
working_data_root=/opt/data
destination_data_root=/mnt/ProNET/Lochness/PHOENIX
site_root=Pronet
conda_env=/opt/software/env/py-feat/
conda_root_path=/opt/miniconda3

### MORE GENERAL COMPONENTS

# for another server with dataflow prerequisites in place and dependencies installed
# - this entire section should be runnable without change
# just update the above server specific settings section in a copy of this file
# (see README for more info)

# setup repo roots and logging
full_path=$(realpath $0)
repo_root=$(dirname $full_path)
if [[ ! -d ${repo_root}/logs ]]; then
	mkdir "$repo_root"/logs
fi
log_timestamp=`date +%s`
exec >  >(tee -ia "$repo_root"/logs/opensmile_feature_logging_"$log_timestamp".txt)
exec 2> >(tee -ia "$repo_root"/logs/opensmile_feature_logging_"$log_timestamp".txt >&2)
verbose_log_path="$repo_root"/logs/opensmile_direct_outputs_"$log_timestamp".txt

# setup exc paths
export PATH="$PATH":"$smile_execute_root"
. "$conda_root_path"/etc/profile.d/conda.sh 
conda activate "$conda_env" 
cd "$working_data_root"

# loop over subjects to find new diary WAVs for processing:
# this code will always extract features using 2 chosen OpenSMILE configs
# as well as following assumptions about AMPSCZ PHOENIX folder structure
# note the WAV copies are provided in the expected AV server location by the above mentioned ProNET pipeline
# therefore that pipeline handles the general rate of processing and enforcement of operation ordering
# (including ensuring that a file in the middle of being copied will not end up partially processed here,
#  as well as preventing a file that has already been processed from being needlessly repeated)
for p in *; do
	# expect within the working data root to see subject_id/phone folders that then contain WAVs to be processed
	if [[ ! -d $p/phone ]]; then
		continue
	fi
	cd "$p"/phone
	wav_count=$(ls -1 *.wav | wc -l)
	if [[ $wav_count == 0 ]]; then
		cd "$working_data_root"
		continue
	fi
	echo "Detected new audio to process for ${p}"
	# setup output folders as needed for this subject, also making sure there is a matching destination subject
	site_id="${p:0:2}"
	if [[ ! -d ${destination_data_root}/PROTECTED/${site_root}${site_id}/processed/${p}/phone/audio_journals ]]; then
		echo "Issue with matching destination directory on PHOENIX, please manually investigate!"
		echo ""
		cd "$working_data_root"
		continue
	fi
	if [[ ! -d ${destination_data_root}/PROTECTED/${site_root}${site_id}/processed/${p}/phone/audio_journals/opensmile_outputs ]]; then
		mkdir "$destination_data_root"/PROTECTED/"$site_root""$site_id"/processed/"$p"/phone/audio_journals/opensmile_outputs
	fi
	if [[ ! -d ${destination_data_root}/PROTECTED/${site_root}${site_id}/processed/${p}/phone/audio_journals/opensmile_outputs/gemaps_lld_csvs ]]; then
		mkdir "$destination_data_root"/PROTECTED/"$site_root""$site_id"/processed/"$p"/phone/audio_journals/opensmile_outputs/gemaps_lld_csvs
	fi
	if [[ ! -d ${destination_data_root}/PROTECTED/${site_root}${site_id}/processed/${p}/phone/audio_journals/opensmile_outputs/is10_paraling_total_csvs ]]; then
		mkdir "$destination_data_root"/PROTECTED/"$site_root""$site_id"/processed/"$p"/phone/audio_journals/opensmile_outputs/is10_paraling_total_csvs
	fi
	if [[ ! -d ${destination_data_root}/PROTECTED/${site_root}${site_id}/processed/${p}/phone/audio_journals/opensmile_outputs/gemaps_monitoring_summary_csvs ]]; then
		mkdir "$destination_data_root"/PROTECTED/"$site_root""$site_id"/processed/"$p"/phone/audio_journals/opensmile_outputs/gemaps_monitoring_summary_csvs
	fi

	# now can loop over the actual wav files!
	# first add current time for runtime tracking purposes - expect ~15% true duration in sum
	now=$(date +"%T")
	echo "Current time: ${now}"
	for file in *.wav; do
		filename=$(echo "$file" | awk -F '.' '{print $1}') 
		firstpart=$(echo "$filename" | awk -F '_audioJournal_' '{print $1}')
		secondpart=$(echo "$filename" | awk -F '_audioJournal_' '{print $2}')
		gemaps_name="$firstpart"_audioJournalFeatures_GeMAPSlld_"$secondpart".csv
		paraling_name="$firstpart"_audioJournalFeatures_IS10Paraling_"$secondpart".csv
		summary_name="$firstpart"_audioJournalFeatures_GeMAPSQuickQC_"$secondpart".csv

		# using configs provided by OpenSMILE 3.0
		# - getting 10 ms level (lld) GeMAPS features using the recommended version by OpenSMILE
		# - getting file level (saved as individual CSV here) IS10 paraling config features, per rec from Jeff Girard
		SMILExtract -C "$smile_config_root"/gemaps/v01b/GeMAPSv01b.conf -I "$file" -lldcsvoutput "$gemaps_name" -instname "$filename" &> "$verbose_log_path"
		SMILExtract -C "$smile_config_root"/is09-13/IS10_paraling.conf -I "$file" -csvoutput "$paraling_name" -instname "$filename" &> "$verbose_log_path"
		
		# now run the python helper to quickly check validity of produced outputs and create basic QC from GeMAPS lld
		# it will also overwrite the other 2 to have comma instead of semicolon delimiter (no reason for these settings not to use comma)
		python "$repo_root"/opensmile_data_check.py "$gemaps_name" "$paraling_name" "$summary_name"
		if [[ ! -e ${summary_name} ]]; then
			echo "OpenSMILE output summary operation failed for audio ${file}, will not mark WAV as done - please manually investigate"
			continue
		fi	
		# the main daily_journal_dataflow_qc code running on the aggregation server will provide monitoring functionalities for these outputs

		# after compute done locally, move to mount so accessible on Lochness PHOENIX file system
		mv "$gemaps_name" "$destination_data_root"/PROTECTED/"$site_root""$site_id"/processed/"$p"/phone/audio_journals/opensmile_outputs/gemaps_lld_csvs/"$gemaps_name"
		mv "$paraling_name" "$destination_data_root"/PROTECTED/"$site_root""$site_id"/processed/"$p"/phone/audio_journals/opensmile_outputs/is10_paraling_total_csvs/"$paraling_name"
		mv "$summary_name" "$destination_data_root"/PROTECTED/"$site_root""$site_id"/processed/"$p"/phone/audio_journals/opensmile_outputs/gemaps_monitoring_summary_csvs/"$summary_name"
		# note daily_journal_dataflow_qc will ensure that curated outputs get to the GENERAL side for eventual move to predict

		# confirm no issue with copying of outputs
		# then leave a marker of processing for ProNET's script and delete the WAV copy that is no longer needed on AV server storage
		if [[ ! -e ${destination_data_root}/PROTECTED/${site_root}${site_id}/processed/${p}/phone/audio_journals/opensmile_outputs/gemaps_lld_csvs/${gemaps_name} ]]; then
			echo "Problem with copying of GeMAPS output for audio ${file}, will not mark WAV as done - please manually investigate"
			continue
		fi
		if [[ ! -e ${destination_data_root}/PROTECTED/${site_root}${site_id}/processed/${p}/phone/audio_journals/opensmile_outputs/is10_paraling_total_csvs/${paraling_name} ]]; then
			echo "Problem with copying of IS10 output for audio ${file}, will not mark WAV as done - please manually investigate"
			continue
		fi
		if [[ ! -e ${destination_data_root}/PROTECTED/${site_root}${site_id}/processed/${p}/phone/audio_journals/opensmile_outputs/gemaps_monitoring_summary_csvs/${summary_name} ]]; then
			echo "Problem with copying of summary output for audio ${file}, will not mark WAV as done - please manually investigate"
			continue
		fi
		echo "done" > "$filename".txt
		echo "Successfully processed ${file}"
		rm "$file"
	done

	echo "Done processing new audio for ${p}"
	now=$(date +"%T")
	echo "Current time: ${now}"
	echo ""
	cd "$working_data_root"
done

# this script does not need to worry about permissions on AV server as it is part of larger root infrastructure
# so should be all done!
