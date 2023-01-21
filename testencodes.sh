#!/bin/bash

#####################################################################
# testencodes - A bash script for x264 test-encoding with VapourSynth
#####################################################################

# DEFAULT VALUES
################

# Vapoursynth script and test folder
testscript="$HOME/encoding/testscript.vpy"
testfolder="$HOME/encoding/tests"

# Default x264 settings
preset="veryslow"
profile="high"
threads="auto"
level='4.1'
badapt='2'
minkeyint='25'
vbvbufsize='78125'
vbvmaxrate='62500'
rclookahead='240'
me='umh'
direct='auto'
subme='11'
trellis='2'
nodctdecimate=1
nofastpskip=1
crf='20'
bitrate='5000'
deblock='-3:-3'
qcomp='0.6'
ipratio='1.30'
pbratio='1.20'
aqmode='3'
aqstrength='0.8'
merange='32'
mbtree=0
psyrd='1:0'
bframes='16'
ref='' #automatically determined by x264

# Initialization of testencodes variables
mode=0 # mode should be 0, 1 (testing mode) or 2 (output mode)
rcm='crf' # rcm (ratecontrol method) should be crf or bitrate
output=''
disc=''
sar=''
zones=''
zfile=''
ow=0
rm=0
clean=0

# Avoid user's local settings to interfere with the script
export LC_NUMERIC=C

# HELP
######

helptest()
{ echo "testencodes v1.1, a bash script for x264 test-encoding with VapourSynth

Syntax: testencodes [options]

Options:

    -t, --test              Choose the x264 setting to test:
                                - crf <min>_<max> <interval>
                                - bitrate <min>_<max> <interval>
                                - deblock <min>_<max>:<deblock-threshold> <interval> or <deblock-strength>:<min>_<max> <interval>
                                - qcomp <min>_<max> <interval>
                                - aq-mode
                                - aq-strength <min>_<max> <interval>
                                - psy-rd <min>_<max>:<psy-trellis> <interval> or <psy-rdo>:<min>_<max> <interval>
                                - ipratio <min>_<max> <interval>
                                - pbratio <min>_<max> <interval>
                                - ipbratio <min>_<max> <interval> where <min>_<max> <interval> apply to ipratio and pbratio = ipratio - 0.1
                                - mbtree
				 						
    -ow, --overwrite        Overwrite test encodes instead of skipping re-encoding.
    
    -rm, --remove           Remove the test encodes for the current tested setting before starting encoding.
    
    -c, --clean             Delete all the test encodes before starting encoding.
    
    -o, --output <string>   If no test is to be performed, output of a single file
	
    -d, --disc <string>     Choose the source disc:
                                - BR
                                  colormatrix and colorprim bt709 are applied
                                - PAL
                                  colormatrix and colorprim bt470bg are applied
                                - NTSC
                                  colormatrix and colorprim smpte170m are applied

    --testscript <string>   Path to your vapoursynth script
                                - $HOME/encoding/scripts/script_v1.vpy

    -h, --help              Display this help
  	
        --preset
        --profile
        --threads
        --level
        --b-adapt
        --min-keyint
        --vbv-bufsize
        --vbv-maxrate
        --rc-lookahead
        --me
        --direct
        --subme
        --trellis
        --crf
        --bitrate
        --deblock
        --qcomp
        --ipratio
        --pbratio
        --aq-mode
        --aq-strength
        --merange
        --psy-rd
        --bframes
        --ref
        --mbtree
        --colormatrix
        --colorprim
        --sar
        --zones <string>    Zones can be loaded from a file with '--zones f:/path/to/file' which each row is:
                            <startframe> <endframe> <crf>
                            Each value is separated with a space.

Example usage:
	
    > Determining the bitrate to work with:
        testencodes -t crf 15_20 1
		
    > Testing qcomp from 0.6 to 0.8 by 0.02 with a working bitrate of 7000kbps:
        testencodes -t qcomp 0.6_0.8 0.02 --bitrate 7000
		
    > Testing aq-mode:
        testencodes -t aq-mode --qcomp 0.68 --bitrate 7000
		
    > Testing aq-strength from 0.5 to 1.2 by 0.1:
        testencodes -t aq-strength 0.5_1.2 0.1 --aq-mode 2 --qcomp 0.68 --bitrate 7000
		
    > Testing psy-rdo from 0.85 to 1.15 by 0.05:
        testencodes -t psy-rd 0.85_1.15:0 0.05 --aq-strength 0.8 --aq-mode 2 --qcomp 0.68 --bitrate 7000
		
    > Testing psy-trellis from 0 to 0.15 by 0.05:
        testencodes -t psy-rd 1.05:0_0.15 0.05 --aq-strength 0.8 --aq-mode 2 --qcomp 0.68 --bitrate 7000
		
    > Testing final crf from 15 to 20 by 1 after deleting existing crf tests:
        testencodes -rm -t crf 15_20 1 --psy-rd 1.05:0.10 --aq-strength 0.8 --aq-mode 2 --qcomp 0.68
		
    > Refining final crf by 0.1 (in this case, tests with crf=17/18 will be skipped as they were already encoded at the previous step):
        testencodes -t crf 17_18 0.1 --psy-rd 1.05:0.10 --aq-strength 0.8 --aq-mode 2 --qcomp 0.68
		
    > Output single file, crf set to 17.3:
        testencodes -o /home/user/encoding/output.mkv --crf 17.3 --psy-rd 1.05:0.10 --aq-strength 0.8 --aq-mode 2 --qcomp 0.68
    
    > Output single file, crf set to 17.3 with a separate script:
        testencodes --testscript /home/user/encoding/script/script.vpy -o /home/user/encoding/output.mkv --crf 17.3 --psy-rd 1.05:0.10 --aq-strength 0.8 --aq-mode 2 --qcomp 0.68
        
    > Cleaning the test folder:
        testencodes -c

Default settings:
    
    Default values can be changed in testencodes.sh
"
}


# READING INPUTS
################

while [ "$1" != "" ]; do
    case $1 in
        -t | --test )           shift
        						mode=1
                                testset=$1
                                
                                if [[ $testset != "aq-mode" ]] && [[ $testset != "mbtree" ]]
								then
				                        shift
				                        if [[ $1 != "-"* ]] && [[ $1 != "" ]] ; then range=$1; else echo -e "Please choose a range and an interval to test $testset.\n"; exit 1; fi
				                fi
                                
                                if [[ $testset != "deblock" ]] && [[ $testset != "psy-rd" ]] && [[ $testset != "aq-mode" ]] && [[ $testset != "mbtree" ]]
                                then
										max=${range#*_}
                                		min=${range%_*}
                                elif [[ $testset = "deblock" ]] || [[ $testset = "psy-rd" ]]
                                then
                                		if [[ $range == *":"* ]]
                                		then
				                        		value1=${range%:*}
				                        		value2=${range#*:}
				                        		if [[ $value1 == *"_"* ]] && [[ $value2 != *"_"* ]]
				                        		then
				                        				if [ $testset = "deblock" ]; then testset="deblock-strength"; else testset="psy-rdo"; fi
				                        				min=${value1%_*}
				                        				max=${value1#*_}
				                        		elif [[ $value2 == *"_"* ]] && [[ $value1 != *"_"* ]]
				                        		then
				                        				if [ $testset = "deblock" ]; then testset="deblock-threshold"; else testset="psy-trellis"; fi
				                        				min=${value2%_*}
				                        				max=${value2#*_}
				                        		else
				                        				if [ $testset = "deblock" ]; then echo -e "You cannot define the range more than once. To test both deblock's strength and threshold from i to j, indicate \"--deblock -i_-j\".\n";exit 1; else echo -e "You cannot test psy-rdo and psy-trellis at the same time.\n"; exit 1; fi
                                				fi
				                        elif [[ $range != *":"* ]]
				                        then
												if [[ $testset != "deblock" ]]; then echo -e "Please choose a psy-trellis value.\n"; exit 1; fi
		                        				min=${range%_*}
		                        				max=${range#*_}
		                        		fi
		                        fi
								
								if [[ $testset != "aq-mode" ]] && [[ $testset != "mbtree" ]] && [[ $testset != "deblock" ]] && [[ $testset != "deblock-strength" ]] && [[ $testset != "deblock-threshold" ]]
								then
									shift
									if [[ $1 != "-"* ]] && [[ $1 != "" ]] ; then int=$1; else echo -e "Please choose an interval to test $testset.\n"; exit 1; fi
								fi
                                
                                ;;
        -d | --disc )			shift
        						disc=$1
        						;;
        -o | --output )			shift
        						mode=2
        						if [[ $1 != "-"* ]] && [[ $1 != "" ]] ; then output="$(echo $1 | sed 's/.mkv//')"; else echo -e "Please indicate a file path for the output.\n"; exit 1; fi
        						;;
       	-ow | --overwrite )		ow=1
       							;;
       	-rm | --remove )        rm=1
       							;;
       	-c | --clean )			clean=1
       							;;
        --preset )		        shift
        						preset=$1
                                ;;
        --testscript )		    shift
        						testscript="$1"
                                ;;
        --profile )		        shift
        						profile=$1
                                ;;
        --threads )		        shift
        						threads=$1
                                ;;
        --level )		        shift
        						level=$1
                                ;;
        --b-adapt )             shift
        						int=$1
                                ;;
        --min-keyint )     	    shift
        						minkeyint=$1
                                ;;
        --vbv-bufsize )  	    shift
        						vbvbufsize=$1
                                ;;
        --vbv-maxrate )   		shift
        						vbvmaxrate=$1
                                ;;
        --rc-lookahead )  		shift
        						rclookahead=$1
                                ;;
        --me )            		shift
        						me=$1
                                ;;
        --direct )     		    shift
        						direct=$1
                                ;;
        --subme )     		    shift
        						subme=$1
                                ;;
        --trellis )     	    shift
        						trellis=$1
                                ;;
        --crf )      		    shift
        						crf=$1
        						rcm='crf'
                                ;;
        --bitrate )				shift
        						bitrate=$1
        						rcm='bitrate'
        						;;
        --deblock )     	    shift
        						deblock=$1
                                ;;
        --qcomp )     		    shift
        						qcomp=$1
                                ;;
        --ipratio )				shift
        						ipratio=$1
        						;;
        --pbratio )				shift
        						pbratio=$1
        						;;
        --aq-mode )      	    shift
        						aqmode=$1
                                ;;
        --aq-strength )         shift
        						aqstrength=$1
                                ;;
        --merange )     	    shift
        						merange=$1
                                ;;
        --psy-rd )     		    shift
        						psyrd=$1
                                ;;
        --bframes )      	    shift
        						bframes=$1
                                ;;
        --ref )      			shift
        						ref=$1
                                ;;
        --mbtree )				shift
        						mbtree=1
        						;;
        --colormatrix )      	shift
        						colormatrix=$1
                                ;;
        --colorprim )      		shift
        						colorprim=$1
                                ;;
        --sar )					shift
        						sar=$1
        						;;
       	--zones)				shift
       							if [[ $1 == "f:"* ]]; then zfile=${1#*f:}; else zones=$1; fi
       							;;
        -h | --help )           helptest
                                exit
                                ;;
        * )                     echo "Undefined setting: $1"
                                exit 1
    esac
    shift
done

# CHECKING REQUIRED FILES AND SOFTWARE
######################################

echo -e ""

if [[ ! -d $testfolder ]]; then echo -e "The test folder $testfolder was not found. Please create the folder or open testencodes.sh to update the path.\n"; exit 1; fi

if [[ ! `vspipe --version` ]]; then echo -e "VapourSynth's command doesn't seem to be recognized by your system. Please check your installation.\n"; exit 1; fi

if [[ ! `x264 --version` ]]; then echo -e "x264's command doesn't seem to be recognized by your system. Please check your installation.\n"; exit 1; fi

if [[ ! -f $testscript ]]; then echo -e "The encoding script $testscript was not found. Please open testencodes.sh to update the file path.\n"; exit 1; fi

# Priority to the tested setting even if crf or bitrate is specified:
if [[ $mode = 1 ]]
then
	if [[ $testset = "crf" ]]; then rcm="crf"; elif [[ $testset = "bitrate" ]]; then rcm="bitrate"; fi
fi

# Read zones file
if [[ $zfile != "" ]]
then
	while read zstart zend zcrf
	do
		    zones="${zones}${zstart},${zend},crf=$zcrf/"
	done < $zfile
	zones="${zones::-1}"
fi

# CLEANING TASK
###############

if [[ $clean == 1 ]]
then			
		rm -rf $testfolder/*
		echo -e "The test folder has been cleaned from all test encodes.\n"
fi


# PREPARING THE ENCODE
######################

# Exiting if no mode is chosen
if [[ $mode == 0 ]]
then
		echo -e "No mode was chosen. Exiting.\n"
		exit 1
fi 

# Boundaries and intervals not defined by user
if [[ "$mode" = 2 ]]
then
		min=1
		max=1
		int=1
fi

if [[ "$testset" = "aq-mode" ]];then
        min="1"
        max="3"
        int="1"
fi

if [[ "$testset" = "mbtree" ]];then
        min="0"
        max="1"
        int="1"
fi

if [[ "$testset" = "deblock" ]] || [[ $testset = "deblock-strength" ]] || [[ $testset = "deblock-threshold" ]];then
        int="1"
fi

# Choice of the color matrix depending on the source disc
if [[ "$disc" = "BR" ]]; then
        colormatrix='bt709'
		colorprim='bt709'
elif [[ "$disc" = "PAL" ]]; then
		colormatrix='bt470bg'
		colorprim='bt470bg'
elif [[ "$disc" = "NTSC" ]]; then
		colormatrix='smpte170m'
		colorprim='smpte170m'
fi

# Creating the test subfolder if necessary
if [[ ! -d  "${testfolder}/${testset}" ]] && [[ $mode == 1 ]] 
then
		mkdir ${testfolder}/${testset};
fi

# Removing task
if [[ $rm == 1 ]]
then			
		rm -rf $testfolder/$testset/*
		echo -e "All test encodes in $testset folder have been deleted.\n"
fi

# Number of test encodes to perform
total=$(bc <<< "scale=0; ($max - $min)/$int+1")


# ENCODING
##########

for i in `seq $min $int $max`;
do
        # Setting to test
        if [[ $mode == 1 ]]; then
        
		    case $testset in
				crf )      		  	    crf=$(printf "%.1f\n" "$i")
										name="crf $crf"
						                ;;
				bitrate )				bitrate="$i"
										name="bitrate $bitrate"
										;;
				deblock-strength )     	deblock="$i:$value2"
						                name="deblock $deblock"
						                ;;
				deblock-threshold )     	deblock="$value1:$i"
						                name="deblock $deblock"
						                ;;
				deblock )				deblock="$i:$i"
										name="deblock $deblock"
										;;
				qcomp )     		    qcomp=$(printf "%.2f\n" "$i")
						                name="qcomp $qcomp"
						                ;;
				ipratio )				ipratio=$(printf "%.2f\n" "$i")
										name="ipratio $ipratio"
										;;
				pbratio )				pbratio=$(printf "%.2f\n" "$i")
										name="pbratio $pbratio"
										;;
				ipbratio )				ipratio=$(printf "%.2f\n" "$i")
										pbratio=$(bc <<< "scale=1; $i-0.10")
										name="ipratio $ipratio pbratio $pbratio"
										;;
				aq-mode )      	 	    aqmode="$i"
						                name="aq-mode $aqmode"
						                ;;
				aq-strength )           aqstrength=$(printf "%.2f\n" "$i")
						                name="aq-strength $aqstrength"
						                ;;
				psy-rdo )     		    psyrd=$(printf "%.2f\n" "$i"):$(printf "%.2f\n" "$value2")
						                name="psyrd $psyrd"
						                ;;
				psy-trellis )     		psyrd=$(printf "%.2f\n" "$value1"):$(printf "%.2f\n" "$i")
						                name="psyrd $psyrd"
						                ;;
				mbtree )				mbtree="$i"
										if [[ $i == "0" ]]; then name="no mbtree"; else name="mbtree"; fi
										;;
				* )                     echo "Unknown test setting: $testset"
						                exit 1
			esac
		fi
		
		# Choice of subfolder
        if [[ $mode == 1 ]] && [[ $testset != "deblock-strength" ]] && [[ $testset != "deblock-threshold" ]]
        then
				output="$testfolder/$testset/$(echo $name | tr ": " "_")"
		elif [[ $testset == "deblock-strength" ]] || [[ $testset == "deblock-threshold" ]]
		then
				output="$testfolder/deblock/$(echo $name | tr ": " "_")"
        fi
        
        # Header
        eta=$(bc <<< "scale=0; ($i - $min)/$int+1")
        if [[ $mode == 1 ]]; then echo -e "($eta/$total) Encoding test with $name\n"; else echo -e "($eta/$total) Encoding output $output.mkv\n"; fi
        
        # If the test doesn't already exist, or if overwrite mode is on:
        if [[ ! -f "$output.mkv" ]] || [[ $ow == 1 ]] || [[ $mode == 2 ]]
        then
        
		    {
		    
		    # Pass 1
		    if [[ $rcm == 'bitrate' ]];then echo -e "> Pass 1"; fi
		    vspipe --y4m "$testscript" - | x264 --demuxer y4m - --preset $preset --profile $profile --threads $threads --level $level --b-adapt $badapt --min-keyint $minkeyint --vbv-bufsize $vbvbufsize --vbv-maxrate $vbvmaxrate --rc-lookahead $rclookahead --me $me --direct $direct --subme $subme --trellis $trellis --no-dct-decimate --no-fast-pskip `if [ $rcm == 'crf' ]; then echo "--crf $crf"; else echo "--bitrate $bitrate --pass 1 --stats $output.stats"; fi` --deblock $deblock --qcomp $qcomp --ipratio $ipratio --pbratio $pbratio --aq-mode $aqmode --aq-strength $aqstrength --merange $merange `if [[ $mbtree == 0 ]]; then echo "--no-mbtree ";fi`--psy-rd $psyrd --bframes $bframes `if [[ $ref != '' ]]; then echo "--ref $ref ";fi``if [[ $colormatrix != '' ]]; then echo "--colormatrix $colormatrix ";fi``if [[ $colorprim != '' ]]; then echo "--colorprim $colorprim ";fi``if [[ $sar != '' ]]; then echo "--sar $sar ";fi``if [[ $zones != '' ]]; then echo "--zones $zones ";fi`--output "$output.mkv"
		    
		    # Pass 2
		    if [[ $rcm == 'bitrate' ]];then
		    
		    	echo -e "\n> Pass 2"
		    	
		    	vspipe --y4m "$testscript" - | x264 --demuxer y4m - --preset $preset --profile $profile --threads $threads --level $level --b-adapt $badapt --min-keyint $minkeyint --vbv-bufsize $vbvbufsize --vbv-maxrate $vbvmaxrate --rc-lookahead $rclookahead --me $me --direct $direct --subme $subme --trellis $trellis --no-dct-decimate --no-fast-pskip --bitrate $bitrate --pass 2 --stats $output.stats --deblock $deblock --qcomp $qcomp --ipratio $ipratio --pbratio $pbratio --aq-mode $aqmode --aq-strength $aqstrength --merange $merange `if [[ $mbtree == 0 ]]; then echo "--no-mbtree ";fi`--psy-rd $psyrd --bframes $bframes `if [[ $ref != '' ]]; then echo "--ref $ref ";fi``if [[ $colormatrix != '' ]]; then echo "--colormatrix $colormatrix ";fi``if [[ $colorprim != '' ]]; then echo "--colorprim $colorprim ";fi``if [[ $sar != '' ]]; then echo "--sar $sar ";fi``if [[ $zones != '' ]]; then echo "--zones $zones ";fi`--output "$output.mkv"
		    
		    fi
		    
		    # create log on the fly
		    } 2>&1 | tee "${output}_tmp.log"
		    
		    # cleaning temporary log and creating final log
		    strings "${output}_tmp.log" | grep -v " frames: \|Output " > "${output}.log"
		    rm "${output}_tmp.log"
		
		# If the test already exists:
		else
			
			echo "Test with $name detected in $testset folder. Skipping the re-encoding."
		
		fi
        
        echo -e ""
        
done