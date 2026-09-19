package com.bcxrr.skillissue;

import com.google.android.gms.games.AnnotatedData;
import com.google.android.gms.games.leaderboard.LeaderboardScore;

public final class LeaderboardScoreHelper {

    private LeaderboardScoreHelper() {
    }

    public static long getRawScore(Object annotatedDataObject) {
        if (!(annotatedDataObject instanceof AnnotatedData<?>)) {
            return -1L;
        }

        AnnotatedData<?> annotatedData =
                (AnnotatedData<?>) annotatedDataObject;

        Object data = annotatedData.get();

        if (!(data instanceof LeaderboardScore)) {
            return -1L;
        }

        LeaderboardScore score =
                (LeaderboardScore) data;

        return score.getRawScore();
    }
}