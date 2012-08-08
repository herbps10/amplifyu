package com.amplifyu.service;

import com.echonest.api.v4.EchoNestException;
import com.echonest.api.v4.Track;

/**
 * @author qingjie zhao.
 * 
 */
public interface TrackService {

	Track getTrackInfo(String API_KEY, String file_name)
			throws EchoNestException;
}
