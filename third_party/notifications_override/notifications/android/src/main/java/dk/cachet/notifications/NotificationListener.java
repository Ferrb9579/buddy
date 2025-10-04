package dk.cachet.notifications;

import android.app.Notification;
import android.os.Build;
import android.os.Bundle;
import android.service.notification.NotificationListenerService;
import android.service.notification.StatusBarNotification;
import android.text.TextUtils;
import android.util.Log;

public class NotificationListener extends NotificationListenerService {
    private static final String TAG = "NotificationListener";

    @Override
    public void onNotificationPosted(StatusBarNotification sbn) {
        try {
            String packageName = sbn.getPackageName();
            Notification notification = sbn.getNotification();
            
            if (notification == null) {
                Log.w(TAG, "Notification is null for package: " + packageName);
                return;
            }

            Bundle extras = notification.extras;
            if (extras == null) {
                Log.w(TAG, "Notification extras are null for package: " + packageName);
                return;
            }

            // Safely extract title with null checks
            CharSequence titleCs = extras.getCharSequence(Notification.EXTRA_TITLE);
            String title = titleCs != null ? titleCs.toString() : "";

            // Safely extract text with null checks
            CharSequence textCs = extras.getCharSequence(Notification.EXTRA_TEXT);
            String text = textCs != null ? textCs.toString() : "";
            
            // If text is empty, try EXTRA_BIG_TEXT
            if (TextUtils.isEmpty(text)) {
                CharSequence bigTextCs = extras.getCharSequence(Notification.EXTRA_BIG_TEXT);
                text = bigTextCs != null ? bigTextCs.toString() : "";
            }

            // Only send if we have at least title or text
            if (!TextUtils.isEmpty(title) || !TextUtils.isEmpty(text)) {
                NotificationsPlugin.sendNotificationEvent(
                    packageName,
                    title,
                    text,
                    sbn.getPostTime()
                );
            } else {
                Log.d(TAG, "Skipping notification with empty title and text from: " + packageName);
            }
        } catch (Exception e) {
            Log.e(TAG, "Error processing notification: " + e.getMessage(), e);
        }
    }

    @Override
    public void onNotificationRemoved(StatusBarNotification sbn) {
        // Handle notification removal if needed
        super.onNotificationRemoved(sbn);
    }
}
