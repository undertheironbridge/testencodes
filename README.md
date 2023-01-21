# testencodes v1.2

This is an improved version of the `testencodes.sh` script used to encode a
VapourSynth-generated stream with x264 with different encoding settings.

## Improvements

### Parallel encodes

The main improvement is the ability to run multiple test (and final) encodes in
parallel. While this doesn't make sense for 1080p with desktop CPUs, you should
be able to run at least two parallel test encodes in 720p on a modern desktop
CPU. How much sense this makes depends on your hardware, your VapourSynth script
, and the options passed to x264.

The script defaults to the old behaviour, which is running a single encode and
waiting for the result. The `--jobs` parameter controls the number of encodes
to run.

This functionality is provided by
[GNU parallel](https://www.gnu.org/software/parallel/sphinx.html) which is now a
required dependency. As such, you can further customise its options by using the
`PARALLEL` environment variable.

### Project directories

You're now required to define the variable `WORKDIR` before starting testencodes
or most of its accompanying scripts. This allows you to have multiple "projects"
which don't interfere with one another. Each "project" has its own VapourSynth
script and a set of options used to create the final encode.

Combined with `--jobs`, this allows you to have multiple test encodes for
multiple "projects" running in parallel.

Helper scripts for initialising the contents of project directories are
provided.

### Automatic resizing

A new option called `--resize` can be passed to testencodes, which will pass an
option called `resizemode` to the VapourSynth script. The supplied script
recognises this option and runs `core.resize.Spline36` to resize the stream to
the desired resolution.

Keep in mind that test encodes for different resolutions in the same project
directory will interfere with one another, i.e. the following will not work and
will end up overwriting one another or erroring out :

```
export WORKDIR=$PWD/work/Strangeways18thBirthday
./testencodes.sh -t crf 17_23 1 --resize 576p &
./testencodes.sh -t crf 17_23 1 --resize 480p &
```

## Usage

Start out by creating a work directory :

```
$ ./make_work_dirs.sh Strangeways18thBirthday
```

The directory `work/Strangeways18thBirthday` should appear, preinitialised with
a copy of `final_args.sh` and `testscript.vpy` from the main directory. You
should now go edit the VapourSynth file to have it do what you want, most
importantly open the source file.

Once that's done, start testencodes with your desired parameters but define
`WORKDIR` as an environment variable before starting it :

```
$ export WORKDIR=$PWD/work/Strangeways18thBirthday
$ ./testencodes.sh -t crf 17_23 1 --resize 576p --jobs 4
See output with: tmux -S /tmp/tmsIi6WY attach
```

You can observe the output by running the given command and attaching to a tmux
session. Testencodes will quit normally once all test encodes complete.

In order to run a comparison against the generated test encodes, you need to
edit your script and change `safe_global('outputmode', 'final')` to
`safe_global('outputmode', 'compare')` and then the `tested_param = 'crf'` line
a few lines below.

Once you have all the encoder settings that you'd like to use for the final
encode, edit the `final_args.sh` file in your project directory. It should
specify the flags to pass to testencodes as a Bash array, potentially providing
different flags for encodes in different resolutions.

When your project's `final_args.sh` is ready, you can run
`make_final_encodes.sh` assuming you still have `WORKDIR` defined :

```
$ ./make_final_encodes.sh
See output with: tmux -S /tmp/tmsPdVYJ attach
```

When run with no parameters, `make_final_encodes.sh` assumes that you want to
create an encode for all resolutions, i.e. 1080p, 720p, 576p, and 480p. If you
want to create only a subset of those, just pass them as arguments, for example
`./make_final_encodes.sh 1080p 576p`. Each of those encodes is run in parallel.
