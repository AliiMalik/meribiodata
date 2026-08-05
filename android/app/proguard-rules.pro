# Flutter supplies its own rules through the Gradle plugin; this file is for
# what the app itself pulls in.

# The Mobile Ads SDK and the consent SDK reflect over their own classes.
-keep class com.google.android.gms.ads.** { *; }
-keep class com.google.android.ump.** { *; }

# WorkManager and Room arrive transitively with play-services-ads-api. Room
# generates its database implementation as <Name>_Impl and instantiates it by
# reflecting on that name, so R8 sees no reference to the class and deletes it.
#
# The failure is invisible at build time and total at run time: the release
# build died on launch with "Failed to create an instance of
# androidx.work.impl.WorkDatabase", from a ContentProvider that runs before any
# Flutter code. Nothing in the Dart layer or the test suite can catch this —
# only installing a real release build does.
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class androidx.work.impl.** { *; }
-keep class * extends androidx.work.ListenableWorker {
    public <init>(android.content.Context, androidx.work.WorkerParameters);
}

# MainActivity is named in AndroidManifest.xml, so it must survive by name.
-keep class safarnamastudios.meribiodata.app.MainActivity { *; }
