import os
import sys
import vapoursynth as vs
import awsmfunc as awf
import havsfunc as haf

core = vs.core

scriptdir = os.path.dirname(os.path.realpath(__file__))

def round_with_subsampling(val):
    sub_factor = 4
    return round(val / sub_factor) * sub_factor;

def resize(clip, target_w, target_h):
	h = round_with_subsampling(target_w * clip.height/clip.width)
	w = round_with_subsampling(target_h * clip.width/clip.height)
	if h > target_h:
		return core.resize.Spline36(clip, w, target_h)
	else:
		return core.resize.Spline36(clip, target_w, h)

def resize_480p(clip):
	return resize(clip, 854, 480)

def resize_576p(clip):
	return resize(clip, 1024, 576)

def resize_720p(clip):
	return resize(clip, 1280, 720)

def open_source(fname):
	if fname.endswith('mkv'):
		return core.ffms2.Source(fname)
	elif fname.endswith('m2ts') or fname.endswith('ts'):
		return core.lsmas.LWLibavSource(fname)
	elif fname.endswith('d2v'):
		return core.d2v.Source(fname)

def safe_global(key, default):
	if key in globals():
		return globals()[key]
	else:
		return default

############

#src = open_source('/absolute/path/to/source')

# inverse telecine
#dtlc = core.vivtc.VFM(clip=src, order=1, mode=5)
#filtered = core.vivtc.VDecimate(dtlc)

# field-blended sources
#ditl = haf.QTGMC(src,Preset='Slow', TR2=1, Sharpness=0.5, SourceMatch=1)
#dblnd = haf.srestore(ditl)

# normal deinterlacing
#src = haf.QTGMC(src,TFF=True, FPSDivisor=2, Preset='Slow', TR2=1, SourceMatch=1)

# some extra filtering
#filtered = core.fb.FillBorders(filtered, left=0, right=0, top=0, bottom=2, mode="fillmargins")
#filtered = haf.FixRowBrightnessProtect2(filtered, row=filtered.height-1, adj_val=50, prot_val=32);
#filtered = core.cf.ContinuityFixer(filtered, left=[4,4,4], top=[0,0,0], right=[0,0,0], bottom=[2,0,0])

# result goes to 'filtered'
filtered = None

############

resmode = safe_global('resizemode', None)

if resmode == '720p':
	resized = resize_720p(filtered)
elif resmode == '576p':
	resized = resize_576p(filtered)
elif resmode == '480p':
	resized = resize_480p(filtered)
else:
	resized = filtered

mode = safe_global('outputmode', 'final')

if mode == 'final':
	resized.set_output()
else:
	extract = awf.SelectRangeEvery(clip=resized, every=3000, length=50, offset=10000)
	
	if mode == 'test':
		extract.set_output()
	elif mode == 'compare':
		extract = awf.FrameInfo(clip=extract, title='Source')
		tested_param = 'crf'
		folder = f'{scriptdir}/tests/{tested_param}'
		comparison = awf.InterleaveDir(folder, PrintInfo=True, first=extract, repeat=True)
		comparison.set_output()
