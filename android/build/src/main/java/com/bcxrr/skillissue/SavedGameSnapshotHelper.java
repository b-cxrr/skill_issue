package com.bcxrr.skillissue;

import com.google.android.gms.games.AnnotatedData;
import com.google.android.gms.games.SnapshotsClient;
import com.google.android.gms.games.snapshot.Snapshot;
import com.google.android.gms.games.snapshot.SnapshotContents;
import com.google.android.gms.games.snapshot.SnapshotMetadata;
import com.google.android.gms.games.snapshot.SnapshotMetadataBuffer;
import com.google.android.gms.games.snapshot.SnapshotMetadataChange;

import java.io.IOException;
import java.nio.charset.StandardCharsets;

public final class SavedGameSnapshotHelper {

    private SavedGameSnapshotHelper() {
    }

    public static String summarizeSnapshots(
            Object annotatedDataObject
    ) {
        if (!(annotatedDataObject instanceof AnnotatedData<?>)) {
            return "error=not_annotated_data";
        }

        AnnotatedData<?> annotatedData =
                (AnnotatedData<?>) annotatedDataObject;

        Object data = annotatedData.get();

        if (!(data instanceof SnapshotMetadataBuffer)) {
            return "error=not_snapshot_buffer";
        }

        SnapshotMetadataBuffer buffer =
                (SnapshotMetadataBuffer) data;

        try {
            int count = buffer.getCount();

            StringBuilder summary = new StringBuilder();

            summary.append("count=");
            summary.append(count);
            summary.append("|files=");

            for (int i = 0; i < count; i++) {
                SnapshotMetadata metadata = buffer.get(i);

                if (i > 0) {
                    summary.append(",");
                }

                summary.append(metadata.getUniqueName());
            }

            return summary.toString();
        } finally {
            buffer.release();
        }
    }

    public static String inspectOpenResult(
            Object openResultObject
    ) {
        if (!(openResultObject
                instanceof SnapshotsClient.DataOrConflict<?>)) {
            return "error=not_data_or_conflict";
        }

        SnapshotsClient.DataOrConflict<?> result =
                (SnapshotsClient.DataOrConflict<?>)
                        openResultObject;

        if (result.isConflict()) {
            return "conflict";
        }

        Object data = result.getData();

        if (!(data instanceof Snapshot)) {
            return "error=not_snapshot";
        }

        return "ok";
    }

    public static Object commitPayload(
            Object snapshotsClientObject,
            Object openResultObject,
            String payload
    ) {
        if (!(snapshotsClientObject instanceof SnapshotsClient)) {
            throw new IllegalArgumentException(
                    "Invalid SnapshotsClient."
            );
        }

        Snapshot snapshot = getOpenedSnapshot(
                openResultObject
        );

        SnapshotContents contents =
                snapshot.getSnapshotContents();

        if (contents == null) {
            throw new IllegalStateException(
                    "Snapshot contents unavailable."
            );
        }

        boolean written = contents.writeBytes(
                payload.getBytes(StandardCharsets.UTF_8)
        );

        if (!written) {
            throw new IllegalStateException(
                    "Snapshot writeBytes returned false."
            );
        }

        SnapshotMetadataChange metadataChange =
                new SnapshotMetadataChange.Builder()
                        .setDescription(
                                "SKILL ISSUE player profile"
                        )
                        .build();

        SnapshotsClient client =
                (SnapshotsClient) snapshotsClientObject;

        return client.commitAndClose(
                snapshot,
                metadataChange
        );
    }

    public static String readPayload(
            Object openResultObject
    ) {
        Snapshot snapshot = getOpenedSnapshot(
                openResultObject
        );

        SnapshotContents contents =
                snapshot.getSnapshotContents();

        if (contents == null) {
            throw new IllegalStateException(
                    "Snapshot contents unavailable."
            );
        }

        try {
            byte[] bytes = contents.readFully();

            return new String(
                    bytes,
                    StandardCharsets.UTF_8
            );
        } catch (IOException exception) {
            throw new IllegalStateException(
                    "Could not read snapshot contents.",
                    exception
            );
        }
    }

    public static Object discardOpenSnapshot(
            Object snapshotsClientObject,
            Object openResultObject
    ) {
        if (!(snapshotsClientObject instanceof SnapshotsClient)) {
            throw new IllegalArgumentException(
                    "Invalid SnapshotsClient."
            );
        }

        Snapshot snapshot = getOpenedSnapshot(
                openResultObject
        );

        SnapshotsClient client =
                (SnapshotsClient) snapshotsClientObject;

        return client.discardAndClose(snapshot);
    }

    private static Snapshot getOpenedSnapshot(
            Object openResultObject
    ) {
        if (!(openResultObject
                instanceof SnapshotsClient.DataOrConflict<?>)) {
            throw new IllegalArgumentException(
                    "Invalid snapshot open result."
            );
        }

        SnapshotsClient.DataOrConflict<?> result =
                (SnapshotsClient.DataOrConflict<?>)
                        openResultObject;

        if (result.isConflict()) {
            throw new IllegalStateException(
                    "Snapshot conflict detected."
            );
        }

        Object data = result.getData();

        if (!(data instanceof Snapshot)) {
            throw new IllegalStateException(
                    "Opened result did not contain a Snapshot."
            );
        }

        return (Snapshot) data;
    }
}