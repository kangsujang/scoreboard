package com.overscore.app.di

import android.content.Context
import androidx.room.Room
import com.overscore.data.AppDatabase
import com.overscore.data.MatchDao
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object AppModule {

    @Provides
    @Singleton
    fun provideDatabase(@ApplicationContext context: Context): AppDatabase {
        return Room.databaseBuilder(
            context,
            AppDatabase::class.java,
            "overscore.db"
        ).build()
    }

    @Provides
    @Singleton
    fun provideMatchDao(database: AppDatabase): MatchDao {
        return database.matchDao()
    }
}
