#!/bin/bash

source common_.sh

if [[ ${BASH_VERSINFO[0]} -lt 4 || (${BASH_VERSINFO[0]} -eq 4 && ${BASH_VERSINFO[1]} -lt 4) ]]; then
  # we make use of "Parameter transformation" (${x[@]@Q}) which was introduced
  # in Bash 4.4
  echo >&2 "This script requires at least Bash 4.4 to run"
  exit 1
fi

#####################################################################
# testencodes - A bash script for x264 test-encoding with VapourSynth
#####################################################################

# DEFAULT VALUES
################
# Vapoursynth script and test folder
if [[ $WORKDIR ]]; then
  testscript="${WORKDIR}/testscript.vpy"
  testfolder="${WORKDIR}/tests"
else
  echo >&2 "Please export WORKDIR before running this script"
  exit 1
fi

# Default x264 settings
declare -A x264settings=(
  ['preset']="veryslow"
  ['profile']="high"
  ['threads']="auto"
  ['level']='4.1'
  ['b-adapt']='2'
  ['keyint']=250
  ['min-keyint']='25'
  ['vbv-bufsize']='78125'
  ['vbv-maxrate']='62500'
  ['rc-lookahead']='240'
  ['me']='umh'
  ['direct']='auto'
  ['subme']='11'
  ['trellis']='2'
  ['no-dct-decimate']=''
  ['no-fast-pskip']=''
  ['deblock']='-3:-3'
  ['qcomp']='0.6'
  ['ipratio']='1.30'
  ['pbratio']='1.20'
  ['aq-mode']='3'
  ['aq-strength']='0.8'
  ['merange']='32'
  ['psy-rd']='1:0'
  ['bframes']='16'
  ['no-mbtree']=''
)

# Initialization of testencodes variables
mode=0 # mode should be 0, 1 (testing mode) or 2 (output mode)
output=''
ow=0
rm=0
clean=0
run_encode=1
vspipeargs=()

# Avoid user's local settings to interfere with the script
export LC_NUMERIC=C

# HELP
######

helptest() {
  echo "testencodes v1.2, a bash script for x264 test-encoding with VapourSynth

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

    -h, --help              Display this help

Standard x264 settings :
"

  for i in "${!x264settings[@]}"; do
    echo "        --${i}"
  done

  echo "
        Zones can be loaded from a file with '--zones f:/path/to/file' which each row is:
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
        
    > Cleaning the test folder:
        testencodes -c

Default settings:
    
    Default values can be changed in testencodes.sh
"
}

export_args() {
  local x264args=()
  for i in "${!x264settings[@]}"; do
    x264args+=("--${i}")
    local val=${x264settings[$i]}
    [[ $val ]] && x264args+=($val)
  done

  local argfile=${output}_args.sh

  cat >"${output}_args.sh" <<EOF
crf=${crf@Q}
bitrate=${bitrate@Q}
output=${output@Q}
testscript=${testscript@Q}
x264args=(${x264args[@]@Q})
vspipeargs=(${vspipeargs[@]@Q})
EOF
}

handle_disc() {
  local disc=$1
  local matrix
  if [[ $disc == "BR" ]]; then
    matrix='bt709'
  elif [[ $disc == "PAL" ]]; then
    matrix='bt470bg'
  elif [[ $disc == "NTSC" ]]; then
    matrix='smpte170m'
  else
    echo >&2 "Unrecognised disc type ${disc}"
    exit 1
  fi

  x264settings['colormatrix']=$matrix
  x264settings['colorprim']=$matrix
}

handle_zones() {
  local arg=$1
  local zones
  if [[ $arg == "f:"* ]]; then
    local zfile=${arg#*f:}
    while read zstart zend zcrf; do
      zones="${zones}${zstart},${zend},crf=$zcrf/"
    done <$zfile
    zones="${zones::-1}"
  else
    zones=$arg
  fi

  x264settings['zones']=$zones
}

# CHECKING REQUIRED FILES AND SOFTWARE
######################################

echo

if [[ ! -f $testscript ]]; then
  echo "The encoding script $testscript was not found. Please open testencodes.sh to update the file path."
  exit 1
fi

if [[ ! -d $testfolder ]]; then
  echo "The test folder $testfolder was not found. Please create the folder or open testencodes.sh to update the path."
  exit 1
fi

if [[ ! $(vspipe --version) ]]; then
  echo "VapourSynth's command doesn't seem to be recognized by your system. Please check your installation."
  exit 1
fi

if [[ ! $(x264 --version) ]]; then
  echo "x264's command doesn't seem to be recognized by your system. Please check your installation."
  exit 1
fi

if [[ ! $(parallel --version) ]]; then
  echo "parallel's command doesn't seem to be recognized by your system. Please check your installation."
  exit 1
fi

if [[ ! $(tmux -V) ]]; then
  echo "tmux's command doesn't seem to be recognized by your system. Please check your installation."
  exit 1
fi

# READING INPUTS
################

while [ "$1" != "" ]; do
  case $1 in
  -t | --test)
    shift
    mode=1
    testset=$1

    if [[ $testset != "aq-mode" ]] && [[ $testset != "mbtree" ]]; then
      shift
      if [[ $1 != "-"* ]] && [[ $1 != "" ]]; then range=$1; else
        echo "Please choose a range and an interval to test $testset."
        exit 1
      fi
    fi

    if [[ $testset != "deblock" ]] && [[ $testset != "psy-rd" ]] && [[ $testset != "aq-mode" ]] && [[ $testset != "mbtree" ]]; then
      max=${range#*_}
      min=${range%_*}
    elif [[ $testset = "deblock" ]] || [[ $testset = "psy-rd" ]]; then
      if [[ $range == *":"* ]]; then
        value1=${range%:*}
        value2=${range#*:}
        if [[ $value1 == *"_"* ]] && [[ $value2 != *"_"* ]]; then
          if [ $testset = "deblock" ]; then testset="deblock-strength"; else testset="psy-rdo"; fi
          min=${value1%_*}
          max=${value1#*_}
        elif [[ $value2 == *"_"* ]] && [[ $value1 != *"_"* ]]; then
          if [ $testset = "deblock" ]; then testset="deblock-threshold"; else testset="psy-trellis"; fi
          min=${value2%_*}
          max=${value2#*_}
        else
          if [ $testset = "deblock" ]; then
            echo "You cannot define the range more than once. To test both deblock's strength and threshold from i to j, indicate \"--deblock -i_-j\"."
            exit 1
          else
            echo "You cannot test psy-rdo and psy-trellis at the same time."
            exit 1
          fi
        fi
      elif [[ $range != *":"* ]]; then
        if [[ $testset != "deblock" ]]; then
          echo "Please choose a psy-trellis value."
          exit 1
        fi
        min=${range%_*}
        max=${range#*_}
      fi
    fi

    if [[ $testset != "aq-mode" ]] && [[ $testset != "mbtree" ]] && [[ $testset != "deblock" ]] && [[ $testset != "deblock-strength" ]] && [[ $testset != "deblock-threshold" ]]; then
      shift
      if [[ $1 != "-"* ]] && [[ $1 != "" ]]; then int=$1; else
        echo "Please choose an interval to test $testset."
        exit 1
      fi
    fi

    ;;
  -d | --disc)
    shift
    handle_disc "$1"
    ;;
  -o | --output)
    shift
    mode=2
    if [[ $1 != "-"* ]] && [[ $1 != "" ]]; then output=${1/\.mkv/}; else
      echo "Please indicate a file path for the output."
      exit 1
    fi
    ;;
  -ow | --overwrite)
    ow=1
    ;;
  -rm | --remove)
    rm=1
    ;;
  -c | --clean)
    clean=1
    ;;
  --crf)
    shift
    crf=$1
    ;;
  --bitrate)
    shift
    bitrate=$1
    ;;
  --ref | --colormatrix | --colorprim | --sar)
    arg=${1#--}
    shift
    x264settings[$arg]=$1
    ;;
  --mbtree)
    unset x264settings['no-mbtree']
    x264settings['mbtree']=''
    ;;
  --zones)
    shift
    handle_zones "$1"
    ;;
  --resize)
    shift
    vspipeargs+=('--arg' "resizemode=$1")
    ;;
  --jobs)
    shift
    jobs=$1
    ;;
  --just-generate)
    run_encode=0
    ;;
  -h | --help)
    helptest
    exit
    ;;
  --*)
    arg=${1#--}
    shift
    if [[ ${x264settings[$arg]} ]]; then
      x264settings[$arg]=$1
    else
      echo >&2 "Undefined setting: --${arg}"
      exit 1
    fi
    ;;
  *)
    echo "Undefined setting: $1"
    exit 1
    ;;
  esac
  shift
done

if [[ $mode -eq 1 ]]; then
  vspipeargs+=('--arg' 'outputmode=test')
fi

# CLEANING TASK
###############

if [[ $clean -eq 1 ]]; then
  rm -rf $testfolder/*
  echo "The test folder has been cleaned from all test encodes."
fi

# PREPARING THE ENCODE
######################

# Exiting if no mode is chosen
if [[ $mode == 0 ]]; then
  echo "No mode was chosen. Exiting."
  exit 1
fi

# Boundaries and intervals not defined by user
if [[ "$mode" = 2 ]]; then
  min=1
  max=1
  int=1
  vspipeargs+=(--arg outputmode=final)
fi

if [[ $testset == "aq-mode" ]]; then
  min="1"
  max="3"
  int="1"
fi

if [[ $testset == "mbtree" ]]; then
  min="0"
  max="1"
  int="1"
  unset x264settings['no-mbtree']
fi

[[ $testset == "deblock" || $testset == "deblock-strength" || $testset == "deblock-threshold" ]] &&
  int=1

# Creating the test subfolder if necessary
[[ $mode == 1 ]] && mkdir -p "${testfolder}/${testset}"

# Removing task
if [[ $rm == 1 ]]; then
  rm -rf "$testfolder/$testset"/*
  echo "All test encodes in $testset folder have been deleted."
fi

# Number of test encodes to perform
total=$(bc <<<"scale=0; ($max - $min)/$int+1")

# ENCODING
##########

for i in $(seq $min $int $max); do
  # Setting to test
  if [[ $mode == 1 ]]; then

    case $testset in
    crf)
      crf=$(printf "%.1f\n" "$i")
      name="crf $crf"
      ;;
    bitrate)
      bitrate="$i"
      name="bitrate $bitrate"
      ;;
    deblock-strength)
      deblock="$i:$value2"
      name="deblock $deblock"
      ;;
    deblock-threshold)
      deblock="$value1:$i"
      name="deblock $deblock"
      ;;
    deblock)
      deblock="$i:$i"
      name="deblock $deblock"
      ;;
    qcomp)
      qcomp=$(printf "%.2f\n" "$i")
      name="qcomp $qcomp"
      ;;
    ipratio)
      ipratio=$(printf "%.2f\n" "$i")
      name="ipratio $ipratio"
      ;;
    pbratio)
      pbratio=$(printf "%.2f\n" "$i")
      name="pbratio $pbratio"
      ;;
    ipbratio)
      ipratio=$(printf "%.2f\n" "$i")
      pbratio=$(bc <<<"scale=1; $i-0.10")
      name="ipratio $ipratio pbratio $pbratio"
      ;;
    aq-mode)
      aqmode="$i"
      name="aq-mode $aqmode"
      ;;
    aq-strength)
      aqstrength=$(printf "%.2f\n" "$i")
      name="aq-strength $aqstrength"
      ;;
    psy-rdo)
      psyrd=$(printf "%.2f\n" "$i"):$(printf "%.2f\n" "$value2")
      name="psyrd $psyrd"
      ;;
    psy-trellis)
      psyrd=$(printf "%.2f\n" "$value1"):$(printf "%.2f\n" "$i")
      name="psyrd $psyrd"
      ;;
    mbtree)
      mbtree="$i"
      if [[ $i == "0" ]]; then name="no mbtree"; else name="mbtree"; fi
      ;;
    *)
      echo "Unknown test setting: $testset"
      exit 1
      ;;
    esac
  fi

  # Choice of subfolder
  if [[ $mode == 1 ]] && [[ $testset != "deblock-strength" ]] && [[ $testset != "deblock-threshold" ]]; then
    output="$testfolder/$testset/${name//[: ]/_}"
  elif [[ $testset == "deblock-strength" ]] || [[ $testset == "deblock-threshold" ]]; then
    output="$testfolder/deblock/${name//[: ]/_}"
  fi

  # If the test doesn't already exist, or if overwrite mode is on:
  if [[ ! -f $output.mkv ]] || [[ $ow == 1 ]] || [[ $mode == 2 ]]; then

    export_args

  # If the test already exists:
  else

    echo "Test with $name detected in $testset folder. Skipping the re-encoding."

  fi

  echo

done

if [[ $run_encode -ne 0 ]]; then
  argfiles=("$testfolder/$testset/"*_args.sh)
  start_runner ${jobs:-1} "${argfiles[@]}"
  rm "${argfiles[@]}"
fi
