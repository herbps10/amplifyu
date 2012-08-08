package com.amplifyu.bean;

/**
 * @author qingjie zhao.
 * 
 */
public class AmplifyU implements java.io.Serializable {

	private static final long serialVersionUID = 9040433275919330713L;

	private int id;
	private String name;
	private String artist;
	private double duration;
	private String file;

	public int getId() {
		return id;
	}

	public void setId(int id) {
		this.id = id;
	}

	public String getName() {
		return name;
	}

	public void setName(String name) {
		this.name = name;
	}

	public String getArtist() {
		return artist;
	}

	public void setArtist(String artist) {
		this.artist = artist;
	}

	public double getDuration() {
		return duration;
	}

	public void setDuration(double duration) {
		this.duration = duration;
	}

	public String getFile() {
		return file;
	}

	public void setFile(String file) {
		this.file = file;
	}

}
