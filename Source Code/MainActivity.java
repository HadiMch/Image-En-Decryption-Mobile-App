package com.example.stega_cryption;

import android.app.Activity;
import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;
import android.provider.DocumentsContract;
import java.io.OutputStream;
import java.util.HashMap;
import java.util.Map;

import androidx.annotation.NonNull;
import io.flutter.embedding.android.FlutterFragmentActivity; // 👈 Important change
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterFragmentActivity { // 👈 Change FlutterActivity → FlutterFragmentActivity
    private static final String CHANNEL = "com.example.stega_cryption";
    private static final int REQUEST_CODE_OPEN_DIRECTORY = 1;
    private MethodChannel.Result pendingResult;
    private Uri selectedFolderUri;

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);

        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
                .setMethodCallHandler((call, result) -> {
                    switch (call.method) {
                        case "getDirectory":
                            pendingResult = result;
                            openDirectoryPicker();
                            break;
                        case "saveEncryptedFileToUri":
                            saveEncryptedFile(call.arguments, result);
                            break;
                        default:
                            result.notImplemented();
                    }
                });
    }

    private void openDirectoryPicker() {
        Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT_TREE);
        intent.addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION);
        intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION | Intent.FLAG_GRANT_WRITE_URI_PERMISSION);
        startActivityForResult(intent, REQUEST_CODE_OPEN_DIRECTORY);
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (requestCode == REQUEST_CODE_OPEN_DIRECTORY && resultCode == Activity.RESULT_OK) {
            Uri uri = data.getData();
            if (uri != null && pendingResult != null) {
                getContentResolver().takePersistableUriPermission(uri,
                        Intent.FLAG_GRANT_READ_URI_PERMISSION | Intent.FLAG_GRANT_WRITE_URI_PERMISSION);
                selectedFolderUri = uri;
                pendingResult.success(uri.toString());
                pendingResult = null;
            }
        }
    }

    private void saveEncryptedFile(Object arguments, MethodChannel.Result result) {
        try {
            Map<String, Object> args = (HashMap<String, Object>) arguments;
            String uriString = (String) args.get("uri");
            String fileName = (String) args.get("fileName");
            byte[] bytes = (byte[]) args.get("bytes");

            Uri folderUri = Uri.parse(uriString);
            Uri fileUri = DocumentsContract.createDocument(
                    getContentResolver(),
                    folderUri,
                    "application/octet-stream",
                    fileName
            );

            if (fileUri != null) {
                OutputStream outputStream = getContentResolver().openOutputStream(fileUri);
                if (outputStream != null) {
                    outputStream.write(bytes);
                    outputStream.close();
                    result.success("Saved");
                    return;
                }
            }

            result.error("SAVE_FAILED", "Failed to write file", null);
        } catch (Exception e) {
            e.printStackTrace();
            result.error("EXCEPTION", e.getMessage(), null);
        }
    }
}
