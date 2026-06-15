package com.overscore.navigation

sealed class Route(val route: String) {
    data object MatchList : Route("matchList")
    data object MatchSetup : Route("matchSetup")
    data class ScoreEditor(val matchId: String) : Route("scoreEditor/{matchId}") {
        companion object {
            const val ROUTE = "scoreEditor/{matchId}"
            fun createRoute(matchId: String) = "scoreEditor/$matchId"
        }
    }
    data class MatchDetail(val matchId: String) : Route("matchDetail/{matchId}") {
        companion object {
            const val ROUTE = "matchDetail/{matchId}"
            fun createRoute(matchId: String) = "matchDetail/$matchId"
        }
    }
    data class Export(val matchId: String) : Route("export/{matchId}") {
        companion object {
            const val ROUTE = "export/{matchId}"
            fun createRoute(matchId: String) = "export/$matchId"
        }
    }
}
