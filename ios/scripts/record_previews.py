"""Record the actual app on available Apple simulators; never substitute devices."""
import argparse,json,pathlib,signal,subprocess,time
def run(*args):
    subprocess.run(args,check=True)
def main():
    p=argparse.ArgumentParser();p.add_argument('--app',required=True);p.add_argument('--out',required=True);a=p.parse_args()
    out=pathlib.Path(a.out).resolve();out.mkdir(parents=True,exist_ok=True)
    runtimes=json.loads(subprocess.check_output(['xcrun','simctl','list','devices','available','--json']))['devices']
    devices=[d for runtime,ds in runtimes.items() if 'iOS' in runtime for d in ds if d.get('isAvailable')]
    (out/'available-simulators.json').write_text(json.dumps(devices,indent=2))
    iphone=next((d for d in devices if 'iPhone' in d['name'] and any(n in d['name'] for n in ['17 Pro','16 Pro','15 Pro'])),None)
    ipad=next((d for d in devices if 'iPad' in d['name'] and '13' in d['name']),None)
    duo=next((d for d in devices if 'iPhone' in d['name'] and 'Duo' in d['name']),None)
    manifest=[]
    for group,device,size in [('iphone-island',iphone,(886,1920)),('ipad',ipad,(1200,1600)),('iphone-duo',duo,(886,1920))]:
        if not device:
            manifest.append({'group':group,'status':'pending_device_runtime','reason':'Matching simulator unavailable; no substitute footage generated.'})
            continue
        udid=device['udid'];folder=out/group;folder.mkdir(exist_ok=True)
        subprocess.run(['xcrun','simctl','shutdown','all'],check=False,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
        run('xcrun','simctl','boot',udid);run('xcrun','simctl','bootstatus',udid,'-b')
        run('xcrun','simctl','ui',udid,'appearance','light')
        run('xcrun','simctl','status_bar',udid,'override','--time','9:41','--dataNetwork','wifi','--wifiMode','active','--wifiBars','3','--batteryState','charged','--batteryLevel','100')
        run('xcrun','simctl','install',udid,str(pathlib.Path(a.app).resolve()))
        for story in range(1,4):
            subprocess.run(['xcrun','simctl','terminate',udid,'com.qiaoyu.vendorbookpro'],check=False,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
            run('xcrun','simctl','launch',udid,'com.qiaoyu.vendorbookpro','--preview-demo','--preview-story',str(story),'-AppleLanguages','(zh-Hant)','-AppleLocale','zh_TW')
            time.sleep(5)
            original=folder/f'0{story}-native-source.mov'
            with (folder/f'0{story}-recording.log').open('w') as log:
                recording=subprocess.Popen(['xcrun','simctl','io',udid,'recordVideo','--codec=h264',str(original)],stdout=log,stderr=log)
                time.sleep(21);recording.send_signal(signal.SIGINT);recording.wait(timeout=30)
            if recording.returncode not in [0,130,-signal.SIGINT]:raise RuntimeError('Simulator recording failed')
            video=folder/f'0{story}-app-preview.mp4';w,h=size
            run('ffmpeg','-y','-loglevel','error','-i',str(original),'-f','lavfi','-i','anullsrc=r=48000:cl=stereo','-t','20','-vf',f'scale={w}:{h}:force_original_aspect_ratio=decrease:force_divisible_by=2,pad={w}:{h}:(ow-iw)/2:(oh-ih)/2:color=white,fps=30,format=yuv420p','-c:v','libx264','-profile:v','high','-level:v','4.0','-b:v','10M','-maxrate','12M','-bufsize','24M','-c:a','aac','-b:a','256k','-movflags','+faststart',str(video))
            run('ffmpeg','-y','-loglevel','error','-ss','5','-i',str(video),'-frames:v','1',str(folder/f'0{story}-poster.png'))
            metadata=json.loads(subprocess.check_output(['ffprobe','-v','error','-show_streams','-show_format','-of','json',str(video)]))
            stream=next(s for s in metadata['streams'] if s['codec_type']=='video')
            assert (stream['width'],stream['height'])==size and stream['r_frame_rate']=='30/1'
            assert 15<=float(metadata['format']['duration'])<=30
            manifest.append({'group':group,'story':story,'device':device['name'],'source':'native_Apple_simulator','status':'recorded_needs_visual_review','file':str(video.relative_to(out)),'format':metadata})
            (out/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2))
    (out/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2))
    if ipad:(out/'ipad-simulator-id.txt').write_text(ipad['udid'])
    if sum(x['status']=='recorded_needs_visual_review' for x in manifest)<6:raise RuntimeError('Required iPhone/iPad runtime unavailable')
if __name__=='__main__':main()
