package com.amplifyu.dao.impl;


import java.util.List;

import org.hibernate.SessionFactory;

import com.amplifyu.bean.AmplifyU;
import com.amplifyu.dao.AmplifyUDao;
/**
 * @author qingjie zhao.
 * 
 */
public class AmplifyUDaoImpl implements AmplifyUDao {

	private SessionFactory sessionFactory;

	public void setSessionFactory(SessionFactory sessionFactory) {
		this.sessionFactory = sessionFactory;
	}

	public List<AmplifyU> findAll() {

		System.out.println("----AmplifyUDaoImpl----");
		return null;
	}

	public boolean insert(AmplifyU amplifyU) {
		
		try {
			System.out.println(".....insert ...");
			this.sessionFactory.getCurrentSession().persist(amplifyU);
			return true;
		} catch (Exception e) {
			e.printStackTrace();
		}
		return false;

	}

}
