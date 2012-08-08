package com.amplifyu.service.impl;

import java.io.File;

import com.amplifyu.service.TrackService;
import com.echonest.api.v4.EchoNestAPI;
import com.echonest.api.v4.EchoNestException;
import com.echonest.api.v4.Track;

/**
 * @author qingjie zhao.
 * 
 */
public class TrackServiceImpl implements TrackService {

	public Track getTrackInfo(String API_KEY, String file_name)
			throws EchoNestException {

		try {
			EchoNestAPI echoNest = new EchoNestAPI(API_KEY);
			//File directory = new File("mp3");
			//String strFile = directory.getAbsolutePath() + "/" + file_name;
			//Track track = echoNest.uploadTrack(new File(strFile), true);
			Track track = echoNest.uploadTrack(new File(file_name), true);
			track.waitForAnalysis(30000);
			return track;
		} catch (Exception e) {
			e.printStackTrace();
		}
		return null;

	}
}
