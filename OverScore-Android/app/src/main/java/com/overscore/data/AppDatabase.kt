package com.overscore.data

import androidx.room.Database
import androidx.room.RoomDatabase
import com.overscore.model.MatchEntity
import com.overscore.model.ScoreEvent

@Database(
    entities = [MatchEntity::class, ScoreEvent::class],
    version = 1,
    exportSchema = false
)
abstract class AppDatabase : RoomDatabase() {
    abstract fun matchDao(): MatchDao
}
