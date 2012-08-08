package com.amplifyu.service.impl;

import java.util.List;

import com.amplifyu.bean.AmplifyU;
import com.amplifyu.dao.AmplifyUDao;
import com.amplifyu.service.AmplifyUService;

/**
 * @author qingjie zhao.
 * 
 */
public class AmplifyUServiceImpl implements AmplifyUService {

	private AmplifyUDao amplifyUDao;

	public void setAmplifyUDao(AmplifyUDao amplifyUDao) {
		this.amplifyUDao = amplifyUDao;
	}

	public List<AmplifyU> findAll() {

		System.out.println("----AmplifyUServiceImpl----");

		return amplifyUDao.findAll();
	}

	public boolean insert(AmplifyU amplifyU) {

		return amplifyUDao.insert(amplifyU);

	}
}
