package com.scoreframe.navigation

import androidx.compose.runtime.Composable
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.scoreframe.ui.export.ExportScreen
import com.scoreframe.ui.matchdetail.MatchDetailScreen
import com.scoreframe.ui.matchlist.MatchListScreen
import com.scoreframe.ui.matchsetup.MatchSetupScreen
import com.scoreframe.ui.scoreeditor.ScoreEditorScreen

@Composable
fun AppNavGraph() {
    val navController = rememberNavController()

    NavHost(
        navController = navController,
        startDestination = Route.MatchList.route
    ) {
        composable(Route.MatchList.route) {
            MatchListScreen(
                onNavigateToSetup = {
                    navController.navigate(Route.MatchSetup.route)
                },
                onNavigateToDetail = { matchId ->
                    navController.navigate(Route.MatchDetail.createRoute(matchId))
                }
            )
        }

        composable(Route.MatchSetup.route) {
            MatchSetupScreen(
                onNavigateToEditor = { matchId ->
                    navController.navigate(Route.ScoreEditor.createRoute(matchId)) {
                        popUpTo(Route.MatchList.route)
                    }
                },
                onNavigateBack = {
                    navController.popBackStack()
                }
            )
        }

        composable(
            route = Route.ScoreEditor.ROUTE,
            arguments = listOf(navArgument("matchId") { type = NavType.StringType })
        ) { backStackEntry ->
            val matchId = backStackEntry.arguments?.getString("matchId") ?: return@composable
            ScoreEditorScreen(
                matchId = matchId,
                onNavigateToDetail = {
                    navController.navigate(Route.MatchDetail.createRoute(matchId)) {
                        popUpTo(Route.MatchList.route)
                    }
                },
                onNavigateBack = {
                    navController.popBackStack()
                }
            )
        }

        composable(
            route = Route.MatchDetail.ROUTE,
            arguments = listOf(navArgument("matchId") { type = NavType.StringType })
        ) { backStackEntry ->
            val matchId = backStackEntry.arguments?.getString("matchId") ?: return@composable
            MatchDetailScreen(
                matchId = matchId,
                onNavigateToExport = {
                    navController.navigate(Route.Export.createRoute(matchId))
                },
                onNavigateToEditor = {
                    navController.navigate(Route.ScoreEditor.createRoute(matchId))
                },
                onNavigateBack = {
                    navController.popBackStack()
                }
            )
        }

        composable(
            route = Route.Export.ROUTE,
            arguments = listOf(navArgument("matchId") { type = NavType.StringType })
        ) { backStackEntry ->
            val matchId = backStackEntry.arguments?.getString("matchId") ?: return@composable
            ExportScreen(
                matchId = matchId,
                onNavigateToList = {
                    navController.navigate(Route.MatchList.route) {
                        popUpTo(Route.MatchList.route) { inclusive = true }
                    }
                },
                onNavigateBack = {
                    navController.popBackStack()
                }
            )
        }
    }
}
