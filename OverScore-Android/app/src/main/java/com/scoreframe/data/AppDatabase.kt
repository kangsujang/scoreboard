package com.scoreframe.data

import androidx.room.Database
import androidx.room.RoomDatabase
import com.scoreframe.model.MatchEntity
import com.scoreframe.model.ScoreEvent

@Database(
    entities = [MatchEntity::class, ScoreEvent::class],
    version = 1,
    exportSchema = false
)
abstract class AppDatabase : RoomDatabase() {
    abstract fun matchDao(): MatchDao
}
