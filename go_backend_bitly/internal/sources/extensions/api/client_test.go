package api

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/zarz/bitly/go_backend_bitly/internal/sources/extensions/runtime"
)

const testExtJS = `var extension={checkAvailability:function(p){if(p.isrc==="valid")return{available:true,track_id:"t1",skip_fallback:false};return{available:false}},getDownloadUrl:function(p){if(p.track_id==="fail")return null;return{url:"https://dl.example.com/"+p.track_id}},download:function(p){if(p.track_id==="fail")return{success:false,error:"failed"};return{success:true,file_path:p.output_path+"/test.mp3",bit_depth:16,sample_rate:44100}},handleUrl:function(p){if(p.url==="invalid")return null;return{type:"track",track:{id:"t1",name:"Test",artists:"A",album_name:"Al",duration_ms:200,cover_url:"c",isrc:"i",track_number:1,genre:"g",label:"l",composer:"c"}}},getLyrics:function(p){if(p.track_name==="null")return null;return{lines:[{startTimeMs:0,words:"hello",endTimeMs:1000}],syncType:"line",instrumental:false,plainLyrics:"hello"}},enrichTrack:function(t){if(!t)return null;var r=JSON.parse(JSON.stringify(t));r.genre="Rock";return r},searchTracks:function(p){if(p.query==="err")return null;if(p.query==="wrapper")return{tracks:[{id:"1",name:"WT"}],total:1};if(p.query==="none")return[];return[{id:"1",name:"Test",artists:"A",album_name:"Al",duration_ms:200,cover_url:"c",isrc:"i"}]},getTrack:function(p){if(p.id==="notfound")return null;return{id:p.id,name:"Track",artists:"A",album_name:"Al",duration_ms:200,cover_url:"c",isrc:"i",track_number:1}},getAlbum:function(p){if(p.id==="notfound")return null;return{id:p.id,name:"Album",artists:"A",cover_url:"c",release_date:"2024",total_tracks:10,tracks:[]}},getArtist:function(p){if(p.id==="notfound")return null;return{id:p.id,name:"Artist",image_url:"img",albums:[],top_tracks:[]}}};`

func setupTestClient(t *testing.T) (*ActionClient, string) {
	t.Helper()
	rt := runtime.NewExtensionRuntime()
	path := filepath.Join(t.TempDir(), "ext.js")
	if err := os.WriteFile(path, []byte(testExtJS), 0644); err != nil {
		t.Fatal(err)
	}
	if err := rt.LoadExtension("test-ext", path); err != nil {
		t.Fatal(err)
	}
	return NewActionClient(rt), "test-ext"
}

func TestNewActionClient(t *testing.T) {
	rt := runtime.NewExtensionRuntime()
	c := NewActionClient(rt)
	if c == nil {
		t.Fatal("expected non-nil client")
	}
}

func TestInvokeAction(t *testing.T) {
	c, extID := setupTestClient(t)
	val, err := c.InvokeAction(extID, "searchTracks", map[string]interface{}{"query": "test", "limit": 5})
	if err != nil {
		t.Fatal(err)
	}
	if val == nil {
		t.Fatal("expected non-nil value")
	}
}

func TestCompatInvokeAction(t *testing.T) {
	_, err := InvokeAction("any", "any", nil)
	if err == nil {
		t.Fatal("expected error from compat function")
	}
}
