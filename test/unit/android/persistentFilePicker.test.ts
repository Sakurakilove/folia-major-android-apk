import { afterEach, describe, expect, it, vi } from 'vitest';
const native=vi.hoisted(()=>({pickFiles:vi.fn(),pickDirectory:vi.fn()}));
vi.mock('@capacitor/core',()=>({registerPlugin:()=>native,Capacitor:{isNativePlatform:()=>true,getPlatform:()=> 'android'}}));
import { installAndroidFileSystem, reviveAndroidDirectoryHandles } from '../../../src/platform/android/androidFileSystem';

// A video pick must retain a revivable SAF document handle instead of degrading to a session-only File input.
afterEach(()=>{vi.unstubAllGlobals();vi.resetAllMocks();});
describe('Android persistent file picker',()=>{
    it('forwards native MIME filters and restores file handles after structured cloning',async()=>{
        const window: Record<string,any>={};vi.stubGlobal('window',window);
        native.pickFiles.mockResolvedValue({entries:[{__foliaAndroidHandle:true,uri:'content://documents/video',kind:'file',name:'video.mp4'}]});
        installAndroidFileSystem();
        const [file]=await window.showOpenFilePicker({multiple:true,types:[{accept:{'video/mp4':['.mp4']}}]});
        expect(native.pickFiles).toHaveBeenCalledWith({multiple:true,mimeTypes:['video/mp4']});
        expect(file.kind).toBe('file');
        const restored=reviveAndroidDirectoryHandles(structuredClone(file));
        expect(restored.uri).toBe('content://documents/video');
        expect(typeof restored.getFile).toBe('function');
    });
    it('maps both native picker cancellation codes to the standard AbortError',async()=>{
        const window:Record<string,any>={};vi.stubGlobal('window',window);installAndroidFileSystem();
        native.pickDirectory.mockRejectedValue({code:'ABORT_ERR'});
        native.pickFiles.mockRejectedValue({code:'AbortError'});
        await expect(window.showDirectoryPicker()).rejects.toMatchObject({name:'AbortError'});
        await expect(window.showOpenFilePicker()).rejects.toMatchObject({name:'AbortError'});
    });
});
