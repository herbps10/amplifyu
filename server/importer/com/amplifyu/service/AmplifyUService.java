package com.amplifyu.service;

import java.util.List;

import com.amplifyu.bean.AmplifyU;
/**
 * @author qingjie zhao.
 * 
 */
public interface AmplifyUService {

	List<AmplifyU> findAll();
	
	boolean insert(AmplifyU amplifyU);
}
