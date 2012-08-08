package com.amplifyu.dao;

import java.util.List;

import com.amplifyu.bean.AmplifyU;

/**
 * @author qingjie zhao.
 * 
 */
public interface AmplifyUDao {

	List<AmplifyU> findAll();

	boolean insert(AmplifyU amplifyU);
}
