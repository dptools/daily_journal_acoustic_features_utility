#!/usr/bin/env python

import pandas as pd
import sys

# helper function to check input OpenSMILE output CSVs are okay 
# plus produce some basic summary features from GeMAPS before moving forward
# (check num rows, 'frameTime' 'Loudness_sma3' and 'F0semitoneFrom27.5Hz_sma3nz' all non-nan num rows, 
#  last entry frameTime, loudness > 0.1 num rows, and pitch != 0 num rows, plus latter two as fractions. 
#  use 'name' as label row)
def opensmile_data_check(gemaps_path, is10_path, save_path):
	try:
		gemaps = pd.read_csv(gemaps_path,sep=';')
		is10 = pd.read_csv(is10_path,sep=';')
	except:
		print("WARNING: unable to load OpenSMILE output paths (" + gemaps_path + ", " + is10_path + "), skipping file")
		return
	if is10.empty:
		print("WARNING: file level output for " + is10_path + " empty, audio needs to be manually inspected")
		return
	if gemaps.empty:
		print("WARNING: file level output for " + gemaps_path + " empty, audio needs to be manually inspected")
		return

	# make comma delimited instead
	gemaps.to_csv(gemaps_path,index=False)
	is10.to_csv(is10_path,index=False)

	# now start sanity checks/summary operations
	num_rows_init = gemaps.shape[0]
	last_stamp_init = gemaps['frameTime'].tolist()[-1]
	gemaps_nonnan = gemaps.dropna(subset=['frameTime','Loudness_sma3','F0semitoneFrom27.5Hz_sma3nz'],how='any')
	num_rows_clean = gemaps_nonnan.shape[0]
	last_stamp_clean = gemaps_nonnan['frameTime'].tolist()[-1]
	num_rows_loud = gemaps_nonnan[gemaps_nonnan['Loudness_sma3'] > 0.1].shape[0]
	num_rows_nonzero = gemaps_nonnan[gemaps_nonnan['F0semitoneFrom27.5Hz_sma3nz'] != 0].shape[0]
	frac_loud = num_rows_loud/float(num_rows_clean)
	frac_nonzero = num_rows_nonzero/float(num_rows_clean)
	fname = gemaps_nonnan['name'].tolist()[0]

	summary_df = pd.DataFrame()
	summary_df["filename"] = [fname]
	summary_df["row_count"] = [num_rows_init]
	summary_df["final_timestamp"] = [last_stamp_init]
	summary_df["filtered_row_count"] = [num_rows_clean]
	summary_df["filtered_final_timestamp"] = [last_stamp_clean]
	summary_df["loud_row_count"] = [num_rows_loud]
	summary_df["nonzero_pitch_count"] = [num_rows_nonzero]
	summary_df["fraction_loud_bins"] = [frac_loud]
	summary_df["fraction_nonzero_bins"] = [frac_nonzero]

	# save as individual CSV to match convention with rest of OpenSMILE process at this stage
	# presence of this CSV will also indicate all OpenSMILE outputs passed basic check
	summary_df.to_csv(save_path, index=False)

if __name__ == '__main__':
	# Map command line arguments to function arguments.
	opensmile_data_check(sys.argv[1], sys.argv[2], sys.argv[3])