# Flutter supplies its own rules through the Gradle plugin; this file is for
# what the app itself pulls in.

# The Mobile Ads SDK and the consent SDK reflect over their own classes.
-keep class com.google.android.gms.ads.** { *; }
-keep class com.google.android.ump.** { *; }

# MainActivity is named in AndroidManifest.xml, so it must survive by name.
-keep class safarnamastudios.meribiodata.app.MainActivity { *; }
