package com.amplifyu.www;

import org.springframework.context.ApplicationContext;
import org.springframework.context.support.ClassPathXmlApplicationContext;

import com.amplifyu.bean.AmplifyU;
import com.amplifyu.service.AmplifyUService;
import com.amplifyu.service.TrackService;
import com.echonest.api.v4.Track;

/**
 * @author qingjie zhao.
 * 
 */
public class Context {

	private static ApplicationContext context;

	// static String strPath = System.getProperty("user.dir") + "/src";

	private static String API_KEY = "BA9W81TWYF81NJF52";
	private static String file_name = "/Users/qingjiezhao/Desktop/DevBox/AmplifyU/qingjie.mp3";

	public static ApplicationContext getContext() {

		if (null == context) {
			String[] s = { "applicationContext-dao.xml",
					"applicationContext-service.xml", "applicationContext.xml",
					"hibernate.cfg.xml" };

			context = new ClassPathXmlApplicationContext(s);
		}
		System.out.println("the context hashcode are :" + context.hashCode());
		return context;
	}

	public static void main(String[] args) throws Exception {

		if (args != null) {

			System.out.println("args.length::" + args.length);

			for (int i = 0; i < args.length; i++) {

				System.out.println("Parameters[" + i + "]'s value is:"
						+ args[i]);

			}

			/* get track info of song from echo nest */
			TrackService trackService = (TrackService) getContext().getBean(
					"trackService");
			Track track = trackService.getTrackInfo(args[0], args[1]);

			// Track track = trackService.getTrackInfo(API_KEY, file_name);
			System.out.println("title is " + track.getTitle());
			System.out.println("duration is " + track.getDuration());
			System.out.println("artist name is " + track.getArtistName());
			System.out.println("Loudness is " + track.getLoudness());
			System.out.println("ReleaseName is " + track.getReleaseName());
			System.out.println("TimeSignature " + track.getTimeSignature());

			/* save info of song to database */
			AmplifyUService userService = (AmplifyUService) getContext()
					.getBean("userService");
			// userService.findAll();
			AmplifyU amplifyU = new AmplifyU();
			amplifyU.setName(track.getTitle());
			amplifyU.setArtist(track.getArtistName());
			amplifyU.setDuration(track.getDuration());
			amplifyU.setFile(args[1]);
			// amplifyU.setFile(file_name);
			boolean bl = userService.insert(amplifyU);
			System.out.println("=======" + bl);

		} else {

			System.out.println("args is null !");

		}

	}
}
