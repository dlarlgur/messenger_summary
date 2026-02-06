-- MySQL dump 10.13  Distrib 8.0.34, for macos13 (x86_64)
--
-- Host: 127.0.0.1    Database: aidb
-- ------------------------------------------------------
-- Server version	8.0.44

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!50503 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `ai_trace`
--

DROP TABLE IF EXISTS `ai_trace`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `ai_trace` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `chat_id` bigint unsigned DEFAULT NULL,
  `stage` enum('SUMMARY','STREAM','YOUTUBE','PRODUCT') DEFAULT NULL,
  `request_json` json DEFAULT NULL,
  `response_json` json DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_chat_stage` (`chat_id`,`stage`)
) ENGINE=InnoDB AUTO_INCREMENT=81 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `ai_trace`
--

LOCK TABLES `ai_trace` WRITE;
/*!40000 ALTER TABLE `ai_trace` DISABLE KEYS */;
INSERT INTO `ai_trace` VALUES (1,6,'SUMMARY','{\"aiDiv\": \"gemini\", \"industry\": \"carwash\", \"question\": \"세차 방법 알려줘\"}','{\"intent\": \"HOW_TO\", \"question\": \"세차 방법 알려줘\", \"productList\": null, \"shortSummary\": \"세차 방법을 알려드립니다.\", \"productKeywords\": null, \"howToSearchKeyword\": \"세차 방법 알려줘\", \"productSearchKeyword\": \"세차 방법 관련 상품\", \"youtubeSearchKeyword\": \"세차 방법 영상\"}','2026-01-12 11:30:06'),(2,8,'SUMMARY','{\"aiDiv\": \"gemini\", \"industry\": \"carwash\", \"question\": \"세차 처음인데 어떻게해?\"}','{\"intent\": \"HOW_TO\", \"question\": \"세차 처음인데 어떻게해?\", \"chatTitle\": \"세차 초보자가이드\", \"productList\": null, \"shortSummary\": \"세차 초보자를 위한 기본 방법 안내\", \"productKeywords\": null, \"howToSearchKeyword\": \"세차 처음 하는 방법\", \"productSearchKeyword\": \"초보자용 세차 용품 추천\", \"youtubeSearchKeyword\": \"세차 처음 하는 방법 영상\"}','2026-01-12 14:49:41'),(3,9,'SUMMARY','{\"aiDiv\": \"gemini\", \"industry\": \"carwash\", \"question\": \"세차방법알려줘\"}','{\"intent\": \"HOW_TO\", \"question\": \"세차방법알려줘\", \"chatTitle\": \"세차 방법 안내\", \"productList\": null, \"shortSummary\": \"세차 방법을 알려드립니다.\", \"productKeywords\": null, \"howToSearchKeyword\": \"세차 방법 알려줘\", \"productSearchKeyword\": \"세차 용품 추천\", \"youtubeSearchKeyword\": \"세차 방법 영상\"}','2026-01-12 15:34:37'),(4,10,'SUMMARY','{\"aiDiv\": \"gemini\", \"industry\": \"carwash\", \"question\": \"세차 방법 알려줘\"}','{\"intent\": \"HOW_TO\", \"question\": \"세차 방법 알려줘\", \"chatTitle\": \"세차 방법 안내\", \"productList\": null, \"shortSummary\": \"세차 방법을 알려드립니다.\", \"productKeywords\": null, \"howToSearchKeyword\": \"세차 방법 알려줘\", \"productSearchKeyword\": \"\", \"youtubeSearchKeyword\": \"세차 방법 영상\"}','2026-01-12 15:53:56'),(5,11,'SUMMARY','{\"aiDiv\": \"gemini\", \"industry\": \"carwash\", \"question\": \"세차 방법쫌 알려줘\"}','{\"intent\": \"HOW_TO\", \"question\": \"세차 방법쫌 알려줘\", \"chatTitle\": \"세차 방법 안내\", \"productList\": null, \"shortSummary\": \"세차 방법을 알려드립니다.\", \"productKeywords\": null, \"howToSearchKeyword\": \"세차 방법 알려줘\", \"productSearchKeyword\": \"\", \"youtubeSearchKeyword\": \"세차 방법 영상\"}','2026-01-12 15:59:39'),(6,12,'SUMMARY','{\"aiDiv\": \"gemini\", \"industry\": \"carwash\", \"question\": \"세차어떻게해\"}','{\"intent\": \"HOW_TO\", \"question\": \"세차어떻게해\", \"chatTitle\": \"세차 방법 문의\", \"productList\": null, \"shortSummary\": \"세차하는 방법을 알려드립니다.\", \"productKeywords\": null, \"howToSearchKeyword\": \"세차하는 방법\", \"productSearchKeyword\": \"세차 용품 추천\", \"youtubeSearchKeyword\": \"세차하는 방법 영상\"}','2026-01-12 16:14:13'),(7,13,'SUMMARY','{\"aiDiv\": \"gemini\", \"industry\": \"carwash\", \"question\": \"세차 어떻게해\"}','{\"intent\": \"HOW_TO\", \"question\": \"세차 어떻게해\", \"chatTitle\": \"세차 방법 문의\", \"productList\": null, \"shortSummary\": \"세차 방법을 알려드립니다.\", \"productKeywords\": null, \"howToSearchKeyword\": \"세차 방법\", \"productSearchKeyword\": \"세차 용품 추천\", \"youtubeSearchKeyword\": \"세차 방법 영상\"}','2026-01-12 16:25:33'),(8,14,'SUMMARY','{\"aiDiv\": \"gemini\", \"industry\": \"carwash\", \"question\": \"세차어떻게해\"}','{\"intent\": \"HOW_TO\", \"question\": \"세차어떻게해\", \"chatTitle\": \"세차 방법 문의\", \"productList\": null, \"shortSummary\": \"세차하는 방법을 알려드립니다.\", \"productKeywords\": null, \"howToSearchKeyword\": \"세차하는 방법\", \"productSearchKeyword\": \"세차 용품 추천\", \"youtubeSearchKeyword\": \"세차하는 방법 영상\"}','2026-01-12 16:30:33'),(9,15,'SUMMARY','{\"aiDiv\": \"gemini\", \"industry\": \"carwash\", \"question\": \"세차어떻게해\"}','{\"intent\": \"HOW_TO\", \"question\": \"세차어떻게해\", \"chatTitle\": \"세차 방법 문의\", \"productList\": null, \"shortSummary\": \"세차하는 방법을 알려드립니다.\", \"productKeywords\": null, \"howToSearchKeyword\": \"세차하는 방법\", \"productSearchKeyword\": \"세차 용품 추천\", \"youtubeSearchKeyword\": \"세차하는 방법 영상\"}','2026-01-12 16:42:06'),(10,16,'SUMMARY','{\"aiDiv\": \"gemini\", \"industry\": \"carwash\", \"question\": \"세차방법알려줘\"}','{\"intent\": \"HOW_TO\", \"question\": \"세차방법알려줘\", \"chatTitle\": \"세차 방법 안내\", \"productList\": null, \"shortSummary\": \"세차 방법을 알려드립니다.\", \"productKeywords\": null, \"howToSearchKeyword\": \"세차 방법 알려줘\", \"productSearchKeyword\": \"세차 용품 추천\", \"youtubeSearchKeyword\": \"세차 방법 영상\"}','2026-01-12 16:54:45'),(11,16,'SUMMARY','{\"aiDiv\": \"gemini\", \"industry\": \"carwash\", \"question\": \"세차방법알려줘\"}','{\"intent\": \"HOW_TO\", \"question\": \"세차방법알려줘\", \"chatTitle\": \"세차 방법 안내\", \"productList\": null, \"shortSummary\": \"세차 방법을 알려드립니다.\", \"productKeywords\": null, \"howToSearchKeyword\": \"세차 방법 알려줘\", \"productSearchKeyword\": \"세차 용품 추천\", \"youtubeSearchKeyword\": \"세차 방법 영상\"}','2026-01-12 16:58:11'),(12,17,'SUMMARY','{\"aiDiv\": \"gemini\", \"industry\": \"carwash\", \"question\": \"세차어떻게해\"}','{\"intent\": \"HOW_TO\", \"question\": \"세차어떻게해\", \"chatTitle\": \"세차 방법 문의\", \"productList\": null, \"shortSummary\": \"세차하는 방법을 알려드릴게요.\", \"productKeywords\": null, \"howToSearchKeyword\": \"세차하는 방법\", \"productSearchKeyword\": \"세차 용품 추천\", \"youtubeSearchKeyword\": \"세차하는 방법 영상\"}','2026-01-13 09:26:24'),(13,18,'SUMMARY','{\"aiDiv\": \"gemini\", \"industry\": \"carwash\", \"question\": \"세차어떻게해\"}','{\"intent\": \"HOW_TO\", \"question\": \"세차어떻게해\", \"chatTitle\": \"세차 방법 문의\", \"productList\": null, \"shortSummary\": \"세차하는 방법을 알려드릴게요.\", \"productKeywords\": null, \"howToSearchKeyword\": \"세차하는 방법\", \"productSearchKeyword\": \"세차 용품 추천\", \"youtubeSearchKeyword\": \"세차하는 방법 영상\"}','2026-01-13 09:31:09'),(14,18,'SUMMARY','{\"aiDiv\": \"gemini\", \"industry\": \"carwash\", \"question\": \"세차어떻게해\"}','{\"intent\": \"HOW_TO\", \"question\": \"세차어떻게해\", \"chatTitle\": \"세차 방법 문의\", \"productList\": null, \"shortSummary\": \"세차하는 방법을 알려드릴게요.\", \"productKeywords\": null, \"howToSearchKeyword\": \"세차하는 방법\", \"productSearchKeyword\": \"세차 용품 추천\", \"youtubeSearchKeyword\": \"세차하는 방법 영상\"}','2026-01-13 09:31:42'),(15,18,'SUMMARY','{\"aiDiv\": \"gemini\", \"industry\": \"carwash\", \"question\": \"세차방법\"}','{\"intent\": \"HOW_TO\", \"question\": \"세차방법\", \"chatTitle\": \"세차 방법\", \"productList\": null, \"shortSummary\": \"세차 방법에 대해 알려드릴게요.\", \"productKeywords\": null, \"howToSearchKeyword\": \"세차 방법\", \"productSearchKeyword\": \"\", \"youtubeSearchKeyword\": \"세차 방법\"}','2026-01-13 09:35:31'),(16,19,'SUMMARY','{\"aiDiv\": \"gemini\", \"industry\": \"carwash\", \"question\": \"세차방법\"}','{\"intent\": \"HOW_TO\", \"question\": \"세차방법\", \"chatTitle\": \"세차 방법\", \"productList\": null, \"shortSummary\": \"세차 방법에 대해 알려드릴게요.\", \"productKeywords\": null, \"howToSearchKeyword\": \"세차 방법\", \"productSearchKeyword\": \"\", \"youtubeSearchKeyword\": \"세차 방법\"}','2026-01-13 09:37:17'),(17,20,'SUMMARY','{\"aiDiv\": \"gemini\", \"industry\": \"carwash\", \"question\": \"세차방법\"}','{\"intent\": \"HOW_TO\", \"question\": \"세차방법\", \"chatTitle\": \"세차 방법\", \"productList\": null, \"shortSummary\": \"세차 방법에 대해 알려드릴게요.\", \"productKeywords\": null, \"howToSearchKeyword\": \"세차 방법\", \"productSearchKeyword\": \"\", \"youtubeSearchKeyword\": \"세차 방법\"}','2026-01-13 09:53:18'),(18,21,'SUMMARY','{\"aiDiv\": \"gemini\", \"industry\": \"carwash\", \"question\": \"세차방법\"}','{\"intent\": \"HOW_TO\", \"question\": \"세차방법\", \"chatTitle\": \"세차 방법\", \"productList\": null, \"shortSummary\": \"세차 방법에 대한 정보를 찾아드릴게요.\", \"productKeywords\": null, \"howToSearchKeyword\": \"세차 방법\", \"productSearchKeyword\": \"\", \"youtubeSearchKeyword\": \"세차 방법\"}','2026-01-13 10:28:33'),(19,22,'SUMMARY','{\"aiDiv\": \"gemini\", \"industry\": \"carwash\", \"question\": \"세차방법 알려줘\"}','{\"intent\": \"HOW_TO\", \"question\": \"세차방법 알려줘\", \"chatTitle\": \"세차 방법 안내\", \"productList\": null, \"shortSummary\": \"세차 방법을 알려드립니다.\", \"productKeywords\": null, \"howToSearchKeyword\": \"세차 방법 알려줘\", \"productSearchKeyword\": \"세차 용품 추천\", \"youtubeSearchKeyword\": \"세차 방법 영상\"}','2026-01-13 10:33:43'),(20,23,'SUMMARY','{\"aiDiv\": \"gemini\", \"industry\": \"carwash\", \"question\": \"슬릭감 좋은 코팅제 추천\"}','{\"intent\": \"PRODUCT\", \"question\": \"슬릭감 좋은 코팅제 추천\", \"chatTitle\": \"슬릭감 좋은 코팅제 추천\", \"productList\": null, \"shortSummary\": \"슬릭감 좋은 세차 코팅제를 추천해 드립니다.\", \"productKeywords\": null, \"howToSearchKeyword\": \"\", \"productSearchKeyword\": \"슬릭감 좋은 세차 코팅제 추천\", \"youtubeSearchKeyword\": \"슬릭감 좋은 세차 코팅제 영상\"}','2026-01-13 10:38:09'),(21,24,'SUMMARY','{\"aiDiv\": \"gemini\", \"industry\": \"carwash\", \"question\": \"슬릭감 좋은코팅제 추천\"}','{\"intent\": \"PRODUCT\", \"question\": \"슬릭감 좋은 코팅제 추천\", \"chatTitle\": \"세차 코팅제 추천\", \"productList\": null, \"shortSummary\": \"슬릭감 좋은 세차 코팅제를 추천해 드립니다.\", \"productKeywords\": null, \"howToSearchKeyword\": \"\", \"productSearchKeyword\": \"슬릭감 좋은 세차 코팅제 추천\", \"youtubeSearchKeyword\": \"슬릭감 좋은 세차 코팅제 영상\"}','2026-01-13 10:38:41'),(22,25,'SUMMARY','{\"aiDiv\": \"gemini\", \"industry\": \"carwash\", \"question\": \"슬릭감 좋은 코팅제 추천\"}','{\"intent\": \"PRODUCT\", \"question\": \"슬릭감 좋은 코팅제 추천\", \"chatTitle\": \"슬릭감 좋은 코팅제 추천\", \"productList\": null, \"shortSummary\": \"슬릭감 좋은 세차 코팅제를 추천해 드립니다.\", \"productKeywords\": null, \"howToSearchKeyword\": \"\", \"productSearchKeyword\": \"슬릭감 좋은 세차 코팅제 추천\", \"youtubeSearchKeyword\": \"슬릭감 좋은 세차 코팅제 영상\"}','2026-01-13 10:46:41'),(23,26,'SUMMARY','{\"aiDiv\": \"gemini\", \"industry\": \"carwash\", \"question\": \"세차방법알려줘\"}','{\"intent\": \"HOW_TO\", \"question\": \"세차방법알려줘\", \"chatTitle\": \"세차 방법 안내\", \"productList\": null, \"shortSummary\": \"세차 방법을 알려드립니다.\", \"productKeywords\": null, \"howToSearchKeyword\": \"세차 방법 알려줘\", \"productSearchKeyword\": \"세차 용품 추천\", \"youtubeSearchKeyword\": \"세차 방법 영상\"}','2026-01-13 11:21:34'),(24,27,'SUMMARY','{\"aiDiv\": \"gemini\", \"industry\": \"carwash\", \"question\": \"세차방법알려줘\"}','{\"intent\": \"HOW_TO\", \"question\": \"세차방법알려줘\", \"chatTitle\": \"세차 방법 안내\", \"productList\": null, \"shortSummary\": \"세차 방법을 알려드립니다.\", \"productKeywords\": null, \"howToSearchKeyword\": \"세차 방법 알려줘\", \"productSearchKeyword\": \"세차 용품 추천\", \"youtubeSearchKeyword\": \"세차 방법 영상\"}','2026-01-13 11:24:31'),(25,27,'SUMMARY','{\"aiDiv\": \"gemini\", \"industry\": \"carwash\", \"question\": \"추천제품\"}','{\"intent\": \"PRODUCT\", \"question\": \"추천제품\", \"chatTitle\": \"세차 추천 제품\", \"productList\": null, \"shortSummary\": \"세차 추천 제품을 찾아드릴게요.\", \"productKeywords\": null, \"howToSearchKeyword\": \"\", \"productSearchKeyword\": \"세차 추천 제품\", \"youtubeSearchKeyword\": \"세차 추천 제품 영상\"}','2026-01-13 11:25:07'),(26,29,'SUMMARY','{\"aiDiv\": \"gemini\", \"industry\": \"carwash\", \"question\": \"3ph세차방법\"}','{\"intent\": \"HOW_TO\", \"question\": \"3ph세차방법\", \"chatTitle\": \"3PH 세차 방법\", \"productList\": null, \"shortSummary\": \"3PH 세차 방법에 대한 정보를 찾아드릴게요.\", \"productKeywords\": null, \"howToSearchKeyword\": \"3PH 세차 방법\", \"productSearchKeyword\": \"\", \"youtubeSearchKeyword\": \"3PH 세차 방법 영상\"}','2026-01-13 12:05:46'),(27,30,'SUMMARY','{\"aiDiv\": \"gemini\", \"industry\": \"carwash\", \"question\": \"3ph세차방법\"}','{\"intent\": \"HOW_TO\", \"question\": \"3ph세차방법\", \"chatTitle\": \"3PH 세차 방법\", \"productList\": null, \"shortSummary\": \"3PH 세차 방법에 대한 정보를 찾아드릴게요.\", \"productKeywords\": null, \"howToSearchKeyword\": \"3PH 세차 방법\", \"productSearchKeyword\": \"\", \"youtubeSearchKeyword\": \"3PH 세차 방법 영상\"}','2026-01-13 12:21:13'),(28,32,'SUMMARY','{\"aiDiv\": \"gemini\", \"industry\": \"carwash\", \"question\": \"3ph세차 용품 알려줘\"}','{\"intent\": \"PRODUCT\", \"question\": \"3ph세차 용품 알려줘\", \"chatTitle\": \"3PH 세차용품 추천\", \"productList\": null, \"shortSummary\": \"3PH 세차에 필요한 용품을 알려드립니다.\", \"productKeywords\": null, \"howToSearchKeyword\": \"3PH 세차 방법 및 용품\", \"productSearchKeyword\": \"3PH 세차 용품 구매\", \"youtubeSearchKeyword\": \"3PH 세차 용품 추천영상\"}','2026-01-13 12:39:33'),(29,33,'SUMMARY','{\"aiDiv\": \"gemini\", \"industry\": \"carwash\", \"question\": \"3ph  세차 용품추천\"}','{\"intent\": \"ALL\", \"question\": \"3ph 세차 용품추천\", \"chatTitle\": \"3PH 세차 용품 추천\", \"productList\": null, \"shortSummary\": \"3PH 세차 방법과 용품 추천을 찾아드릴게요.\", \"productKeywords\": null, \"howToSearchKeyword\": \"3PH 세차 방법 및 용품 추천\", \"productSearchKeyword\": \"3PH 세차 용품 추천\", \"youtubeSearchKeyword\": \"3PH 세차 용품 추천 영상\"}','2026-01-13 12:46:13'),(30,34,'SUMMARY','{\"aiDiv\": \"gemini\", \"industry\": \"carwash\", \"question\": \"3ph  세차 방법\"}','{\"intent\": \"HOW_TO\", \"question\": \"3ph 세차 방법\", \"chatTitle\": \"3PH 세차 방법\", \"productList\": null, \"shortSummary\": \"3PH 세차 방법을 알려드립니다.\", \"productKeywords\": null, \"howToSearchKeyword\": \"3PH 세차 방법\", \"productSearchKeyword\": \"3PH 세차 용품 추천\", \"youtubeSearchKeyword\": \"3PH 세차 방법 영상\"}','2026-01-13 12:57:08'),(31,35,'SUMMARY','{\"aiDiv\": \"gemini\", \"industry\": \"carwash\", \"question\": \"3ph  세차 방법\"}','{\"intent\": \"HOW_TO\", \"question\": \"3ph 세차 방법\", \"chatTitle\": \"3PH 세차 방법\", \"productList\": null, \"shortSummary\": \"3PH 세차 방법을 알려드립니다.\", \"productKeywords\": null, \"howToSearchKeyword\": \"3PH 세차 방법\", \"productSearchKeyword\": \"3PH 세차 용품 추천\", \"youtubeSearchKeyword\": \"3PH 세차 방법 영상\"}','2026-01-13 13:04:07'),(32,36,'SUMMARY','{\"aiDiv\": \"gemini\", \"industry\": \"carwash\", \"question\": \"3ph  세차방법 상세히 알려줘\"}','{\"intent\": \"HOW_TO\", \"question\": \"3ph 세차방법 상세히 알려줘\", \"chatTitle\": \"3PH 세차 방법 상세 안내\", \"productList\": null, \"shortSummary\": \"3PH 세차 방법에 대한 상세 정보를 알려드립니다.\", \"productKeywords\": null, \"howToSearchKeyword\": \"3PH 세차 방법 상세히 알려줘\", \"productSearchKeyword\": \"3PH 세차 관련 용품 추천\", \"youtubeSearchKeyword\": \"3PH 세차방법 영상\"}','2026-01-13 13:09:05'),(33,36,'SUMMARY','{\"aiDiv\": \"gemini\", \"industry\": \"carwash\", \"question\": \"어떤제품 써야해?\"}','{\"intent\": \"PRODUCT\", \"question\": \"어떤제품 써야해?\", \"chatTitle\": \"세차 제품 추천\", \"productList\": null, \"shortSummary\": \"세차에 사용할 제품을 추천해 드립니다.\", \"productKeywords\": null, \"howToSearchKeyword\": \"\", \"productSearchKeyword\": \"세차 제품 추천\", \"youtubeSearchKeyword\": \"\"}','2026-01-13 13:09:22'),(34,36,'SUMMARY','{\"aiDiv\": \"gemini\", \"industry\": \"carwash\", \"question\": \"어떤제품 써야해\"}','{\"intent\": \"PRODUCT\", \"question\": \"어떤제품 써야해\", \"chatTitle\": \"세차 제품 추천\", \"productList\": null, \"shortSummary\": \"세차 제품 추천\", \"productKeywords\": null, \"howToSearchKeyword\": \"\", \"productSearchKeyword\": \"세차 제품 추천\", \"youtubeSearchKeyword\": \"\"}','2026-01-13 13:10:13'),(35,36,'SUMMARY','{\"aiDiv\": \"gemini\", \"industry\": \"carwash\", \"question\": \"3ph  세차용품 추천\"}','{\"intent\": \"PRODUCT\", \"question\": \"3ph 세차용품 추천\", \"chatTitle\": \"3PH 세차용품 추천\", \"productList\": null, \"shortSummary\": \"3PH 세차용품을 추천해 드립니다.\", \"productKeywords\": null, \"howToSearchKeyword\": \"\", \"productSearchKeyword\": \"3PH 세차용품 추천\", \"youtubeSearchKeyword\": \"3PH 세차용품 영상\"}','2026-01-13 13:14:07'),(36,36,'SUMMARY','{\"aiDiv\": \"gemini\", \"industry\": \"carwash\", \"question\": \"3ph세차 용품추천\"}','{\"intent\": \"ALL\", \"question\": \"3ph세차 용품추천\", \"chatTitle\": \"3PH 세차 용품추천\", \"productList\": null, \"shortSummary\": \"3PH 세차 방법과 용품 추천을 찾아드릴게요.\", \"productKeywords\": null, \"howToSearchKeyword\": \"3PH 세차 방법 및 용품 추천\", \"productSearchKeyword\": \"3PH 세차 용품 추천\", \"youtubeSearchKeyword\": \"3PH 세차 용품추천 영상\"}','2026-01-13 13:16:56'),(37,36,'SUMMARY','{\"aiDiv\": \"gemini\", \"industry\": \"carwash\", \"question\": \"3ph세차 용품추천해줘\"}','{\"intent\": \"ALL\", \"question\": \"3ph세차 용품추천해줘\", \"chatTitle\": \"3PH 세차 용품 추천\", \"productList\": null, \"shortSummary\": \"3PH 세차 방법과 용품 추천\", \"productKeywords\": null, \"howToSearchKeyword\": \"3PH 세차 방법 및 용품\", \"productSearchKeyword\": \"3PH 세차 용품 추천\", \"youtubeSearchKeyword\": \"3PH 세차 용품 추천 영상\"}','2026-01-13 13:17:19'),(38,36,'SUMMARY','{\"aiDiv\": \"gemini\", \"industry\": \"carwash\", \"question\": \"3ph 세차용품 추천\"}','{\"intent\": \"PRODUCT\", \"question\": \"3ph 세차용품 추천\", \"chatTitle\": \"3PH 세차용품 추천\", \"productList\": null, \"shortSummary\": \"3PH 세차 용품을 추천해 드립니다.\", \"productKeywords\": null, \"howToSearchKeyword\": \"\", \"productSearchKeyword\": \"3PH 세차 용품 추천\", \"youtubeSearchKeyword\": \"3PH 세차 용품\"}','2026-01-13 13:18:40'),(39,37,'SUMMARY','{\"aiDiv\": \"gemini\", \"industry\": \"carwash\", \"question\": \"3ph  세차 용품 추천\"}','{\"intent\": \"PRODUCT\", \"question\": \"3ph 세차 용품 추천\", \"chatTitle\": \"3PH 세차 용품 추천\", \"productList\": null, \"shortSummary\": \"3PH 세차 용품을 추천해 드립니다.\", \"productKeywords\": null, \"howToSearchKeyword\": \"\", \"productSearchKeyword\": \"3PH 세차 용품 추천\", \"youtubeSearchKeyword\": \"3PH 세차 방법 및 용품\"}','2026-01-13 13:24:46'),(40,38,'SUMMARY','{\"aiDiv\": \"gemini\", \"industry\": \"carwash\", \"question\": \"3ph  세차용품 추천\"}','{\"intent\": \"PRODUCT\", \"question\": \"3ph 세차용품 추천\", \"chatTitle\": \"3PH 세차용품 추천\", \"productList\": null, \"shortSummary\": \"3PH 세차용품을 추천해 드립니다.\", \"productKeywords\": null, \"howToSearchKeyword\": \"\", \"productSearchKeyword\": \"3PH 세차용품 추천\", \"youtubeSearchKeyword\": \"3PH 세차용품 영상\"}','2026-01-13 13:28:10'),(41,39,'SUMMARY','{\"aiDiv\": \"gemini\", \"industry\": \"carwash\", \"question\": \"3ph  세차 용품 추천\"}','{\"intent\": \"PRODUCT\", \"question\": \"3ph 세차 용품 추천\", \"chatTitle\": \"3PH 세차 용품 추천\", \"productList\": null, \"shortSummary\": \"3PH 세차 용품을 추천해 드립니다.\", \"productKeywords\": null, \"howToSearchKeyword\": \"\", \"productSearchKeyword\": \"3PH 세차 용품 추천\", \"youtubeSearchKeyword\": \"3PH 세차 방법 및 용품\"}','2026-01-13 13:33:41'),(42,40,'SUMMARY','{\"aiDiv\": \"gemini\", \"industry\": \"carwash\", \"question\": \"세트 말고 각각 추천해줘\"}','{\"intent\": \"PRODUCT\", \"question\": \"세트 말고 각각 추천해줘\", \"chatTitle\": \"세차용품 개별 추천\", \"productList\": null, \"shortSummary\": \"세차용품 개별 추천을 원하시면 말씀해주세요.\", \"productKeywords\": null, \"howToSearchKeyword\": \"\", \"productSearchKeyword\": \"세차용품 개별 추천\", \"youtubeSearchKeyword\": \"\"}','2026-01-13 13:34:53'),(43,41,'SUMMARY','{\"aiDiv\": \"gemini\", \"industry\": \"carwash\", \"question\": \"3ph 세차 용품 각각 추천해줘\"}','{\"intent\": \"ALL\", \"question\": \"3ph 세차 용품 각각 추천해줘\", \"chatTitle\": \"3PH 세차 용품 추천\", \"productList\": null, \"shortSummary\": \"3PH 세차 용품 추천\", \"productKeywords\": null, \"howToSearchKeyword\": \"3PH 세차 방법 및 용품\", \"productSearchKeyword\": \"3PH 세차 용품 추천\", \"youtubeSearchKeyword\": \"3PH세차 용품 추천 영상\"}','2026-01-13 13:36:05'),(44,42,'SUMMARY','{\"aiDiv\": \"gemini\", \"industry\": \"carwash\", \"question\": \"3ph  세차용품 각각 추천해줘\"}','{\"intent\": \"ALL\", \"question\": \"3ph 세차용품 각각 추천해줘\", \"chatTitle\": \"3PH 세차 용품 추천\", \"productList\": null, \"shortSummary\": \"3PH 세차 용품 추천\", \"productKeywords\": null, \"howToSearchKeyword\": \"3PH 세차 방법 및 용품\", \"productSearchKeyword\": \"3PH 세차 용품 추천\", \"youtubeSearchKeyword\": \"3PH 세차용품 추천 영상\"}','2026-01-13 13:38:09'),(45,43,'SUMMARY','{\"aiDiv\": \"gemini\", \"industry\": \"carwash\", \"question\": \"3ph 세차용품 각각 추천\"}','{\"intent\": \"PRODUCT\", \"question\": \"3ph 세차용품 각각 추천\", \"chatTitle\": \"3PH 세차 용품 추천\", \"productList\": null, \"shortSummary\": \"3PH 세차 용품 추천\", \"productKeywords\": null, \"howToSearchKeyword\": \"\", \"productSearchKeyword\": \"3PH 세차 용품 추천\", \"youtubeSearchKeyword\": \"3PH 세차 용품 추천 영상\"}','2026-01-13 13:39:58'),(46,44,'SUMMARY','{\"aiDiv\": \"gemini\", \"industry\": \"carwash\", \"question\": \"세차 어떻게하는지 알려줘\"}','{\"intent\": \"HOW_TO\", \"question\": \"세차 어떻게하는지 알려줘\", \"chatTitle\": \"세차 방법 안내\", \"productList\": null, \"shortSummary\": \"세차 방법을 알려드립니다.\", \"productKeywords\": null, \"howToSearchKeyword\": \"세차 방법 알려줘\", \"productSearchKeyword\": \"세차 용품 추천\", \"youtubeSearchKeyword\": \"세차 방법 영상\"}','2026-01-13 17:37:56'),(47,45,'SUMMARY','{\"aiDiv\": \"gemini\", \"industry\": \"carwash\", \"question\": \"세차방법\"}','{\"intent\": \"HOW_TO\", \"question\": \"세차방법\", \"chatTitle\": \"세차 방법\", \"productList\": null, \"shortSummary\": \"세차 방법에 대한 정보를 찾아드릴게요.\", \"productKeywords\": null, \"howToSearchKeyword\": \"세차 방법\", \"productSearchKeyword\": \"\", \"youtubeSearchKeyword\": \"세차 방법\"}','2026-01-13 17:38:56'),(48,46,'SUMMARY','{\"aiDiv\": \"gemini\", \"history\": null, \"industry\": \"carwash\", \"question\": \"슬릭감 좋은 세차 용품 알려줘\", \"isFirstChat\": true}','{\"intent\": \"PRODUCT\", \"question\": \"슬릭감 좋은 세차 용품 알려줘\", \"chatTitle\": \"슬릭감 좋은 세차 용품 추천\", \"productList\": null, \"shortSummary\": \"슬릭감 좋은 세차 용품 추천\", \"productKeywords\": null, \"howToSearchKeyword\": \"\", \"productSearchKeyword\": \"슬릭감 좋은 세차 용품 추천\", \"youtubeSearchKeyword\": \"\"}','2026-01-15 14:26:54'),(49,47,'SUMMARY','{\"aiDiv\": \"gemini\", \"history\": null, \"industry\": \"carwash\", \"question\": \"슬릭감 좋은 코팅제 추천\", \"isFirstChat\": true}','{\"intent\": \"PRODUCT\", \"question\": \"슬릭감 좋은 코팅제 추천\", \"chatTitle\": \"세차 코팅제 추천\", \"productList\": null, \"shortSummary\": \"슬릭감 좋은 세차 코팅제를 추천해 드립니다.\", \"productKeywords\": null, \"howToSearchKeyword\": \"\", \"productSearchKeyword\": \"슬릭감 좋은 세차 코팅제 추천\", \"youtubeSearchKeyword\": \"\"}','2026-01-15 14:37:45'),(50,48,'SUMMARY','{\"aiDiv\": \"gemini\", \"history\": null, \"industry\": \"carwash\", \"question\": \"슬릭감 좋은 코팅제\", \"isFirstChat\": true}','{\"intent\": \"PRODUCT\", \"question\": \"슬릭감 좋은 코팅제\", \"chatTitle\": \"슬릭감 좋은 코팅제 추천\", \"productList\": null, \"shortSummary\": \"슬릭감 좋은 세차 코팅제를 추천해 드립니다.\", \"productKeywords\": null, \"howToSearchKeyword\": \"\", \"productSearchKeyword\": \"슬릭감 좋은 세차 코팅제 추천\", \"youtubeSearchKeyword\": \"슬릭감 좋은 세차 코팅제 영상\"}','2026-01-15 14:55:09'),(51,49,'SUMMARY','{\"aiDiv\": \"gemini\", \"history\": null, \"industry\": \"carwash\", \"question\": \"슬릭감 좋은 세차코팅제 알려줘\", \"isFirstChat\": true}','{\"intent\": \"PRODUCT\", \"question\": \"슬릭감 좋은 세차코팅제 알려줘\", \"chatTitle\": \"슬릭감 좋은 세차 코팅제 추천\", \"productList\": null, \"shortSummary\": \"슬릭감 좋은 세차 코팅제 추천\", \"productKeywords\": null, \"howToSearchKeyword\": \"슬릭감 좋은 세차 코팅제 세차 방법\", \"productSearchKeyword\": \"슬릭감 좋은 세차 코팅제 추천\", \"youtubeSearchKeyword\": \"슬릭감 좋은 세차 코팅제 추천 영상\"}','2026-01-15 14:58:26'),(52,50,'SUMMARY','{\"aiDiv\": \"gemini\", \"history\": null, \"industry\": \"carwash\", \"question\": \"세차방법 알려줘\", \"isFirstChat\": true}','{\"intent\": \"HOW_TO\", \"question\": \"세차방법 알려줘\", \"chatTitle\": \"세차 방법 안내\", \"productList\": null, \"shortSummary\": \"세차 방법을 알려드립니다.\", \"productKeywords\": null, \"howToSearchKeyword\": \"세차 방법 알려줘\", \"productSearchKeyword\": \"세차 용품 추천\", \"youtubeSearchKeyword\": \"세차 방법 영상\"}','2026-01-15 14:59:27'),(53,51,'SUMMARY','{\"aiDiv\": \"gemini\", \"history\": null, \"industry\": \"carwash\", \"question\": \"세차방법\", \"isFirstChat\": true}','{\"intent\": \"HOW_TO\", \"question\": \"세차방법\", \"chatTitle\": \"세차 방법\", \"productList\": null, \"shortSummary\": \"세차 방법에 대한 정보를 찾아드릴게요.\", \"productKeywords\": null, \"howToSearchKeyword\": \"세차 방법\", \"productSearchKeyword\": \"\", \"youtubeSearchKeyword\": \"세차 방법\"}','2026-01-15 15:06:07'),(54,52,'SUMMARY','{\"aiDiv\": \"gemini\", \"history\": null, \"industry\": \"carwash\", \"question\": \"세차방법\", \"isFirstChat\": true}','{\"intent\": \"HOW_TO\", \"question\": \"세차방법\", \"chatTitle\": \"세차 방법\", \"productList\": null, \"shortSummary\": \"세차 방법에 대한 정보를 찾아드릴게요.\", \"productKeywords\": null, \"howToSearchKeyword\": \"세차 방법\", \"productSearchKeyword\": \"\", \"youtubeSearchKeyword\": \"세차 방법\"}','2026-01-15 15:09:59'),(55,53,'SUMMARY','{\"aiDiv\": \"gemini\", \"history\": null, \"industry\": \"carwash\", \"question\": \"세차방법\", \"isFirstChat\": true}','{\"intent\": \"HOW_TO\", \"question\": \"세차방법\", \"chatTitle\": \"세차 방법 안내\", \"productList\": null, \"shortSummary\": \"세차하는 방법을 알려드릴게요.\", \"productKeywords\": null, \"howToSearchKeyword\": \"세차 방법 알려줘\", \"productSearchKeyword\": \"\", \"youtubeSearchKeyword\": \"세차 방법 영상\"}','2026-01-15 15:20:57'),(56,53,'SUMMARY','{\"aiDiv\": \"gemini\", \"history\": [{\"role\": \"user\", \"content\": \"세차방법\"}, {\"role\": \"assistant\", \"content\": \"세차하는 방법을 알려드릴게요.\\n\\n세\\n\\n차는 크게 두 가지 방법으로 나눌 수 있습니다.\\n**1. 셀\\n\\n프 세차:**\\n*   **준비물:**\\n  *   카샴푸 (차량용)\\n  *   세차용 스펀지 또는 워시미트\\n  *   버킷 (두 개를\\n\\n준비하면 샴푸물과 헹굼물을 분리하여 사용할 수 있어 더욱 좋습니다.)\\n  *   드라잉 타월 (물기를 닦는 용도, 여러 장 준비하면 편리합니다.)\\n  *   휠\\n\\n클리너 및 휠 브러쉬 (휠 세척 시 필요)\\n  *   유리 세정제 및 유리 전용 타월 (유리 세척 시 필요)\\n  *   (선택 사항) 타\\n\\n이어 광택제, 실내 클리너, 물왁스 등\\n*   **세차 순서:**\\n  1.  **차량 전체에 물 뿌리기:** 먼지나 흙을 불려 제거하기 쉽게\\n\\n합니다. 고압수를 사용하면 효과적입니다.\\n  2.  **휠 세척:** 휠 클리너를 뿌리고 브러쉬로 문질러 휠의 오염물을 제거합니다.\\n  3\\n\\n.  **카샴푸 묻혀 세차:** 버킷에 카샴푸와 물을 섞어 거품을 낸 후, 스펀지나 워시미트에 묻혀 차량의 위에서부터 아래로\\n\\n닦아냅니다. 한 번에 넓은 면적보다는 구역을 나누어 닦는 것이 좋습니다.\\n  4.  **헹굼:** 깨끗한 물로 차량 전체에 묻은 샴푸 거\\n\\n품을 깨끗하게 헹궈냅니다.\\n  5.  **물기 제거 (드라잉):** 드라잉 타월을 사용하여 차량의 물기를 꼼꼼하게 닦아냅니다. 물\\n\\n기가 남아있으면 물 얼룩이 생길 수 있습니다.\\n  6.  **유리 세척:** 유리 세정제를 뿌리고 유리 전용 타월로 닦아 깨끗하게 만듭니다.\\n  7\\n\\n.  **(선택 사항) 마무리:** 타이어 광택제를 바르거나, 물왁스를 사용하여 광택을 더하고 차량을 보호할 수 있습니다. 실내 세차도 함께 진행하면 좋습니다.\\n**2. 자동\\n\\n세차:**\\n*   **장점:** 빠르고 간편하게 세차할 수 있습니다.\\n*   **단점:** 차량에 미세한 흠집이 생길 가능성이 있으며, 꼼꼼하게 세척되지\\n\\n않는 부분이 있을 수 있습니다.\\n*   **이용 시 주의사항:**\\n  *   차량 외부의 안테나, 와이퍼, 사이드 미러 등을 접거나 고정합니다.\\n  *   차\\n\\n량 내부의 창문을 모두 닫습니다.\\n  *   세차 전 차량 외부의 큰 이물질(나뭇가지, 돌 등)은 미리 제거합니다.\\n**세차 시 유의사항:**\\n*   \\n\\n**햇볕이 강한 날은 피하세요:** 햇볕이 강한 날 세차하면 물기가 빨리 말라 물 얼룩이 생기기 쉽습니다. 흐린 날이나 해가 지기 시작할 때 세차\\n\\n하는 것이 좋습니다.\\n*   **차량의 위에서부터 아래로:** 오염물이 위에서 아래로 흘러내리기 때문에, 위에서부터 닦아야 효율적입니다.\\n*   **깨끗한 용\\n\\n품 사용:** 오염된 스펀지나 타월을 사용하면 차량에 흠집이 생길 수 있습니다.\\n*   **주기적인 세차:** 차량을 깨끗하게 유지하면 도장면 보호에도 도움이 됩니다.\\n어\\n\\n떤 방법으로 세차하시겠어요? 더 궁금한 점이 있으시면 언제든지 물어보세요!\\n\\n\"}], \"industry\": \"carwash\", \"question\": \"세차방법\", \"isFirstChat\": false}','{\"intent\": \"HOW_TO\", \"question\": \"세차방법\", \"chatTitle\": \"세차 방법 안내\", \"productList\": null, \"shortSummary\": \"세차하는 방법을 알려드립니다.\", \"productKeywords\": null, \"howToSearchKeyword\": \"세차 방법\", \"productSearchKeyword\": \"세차 용품 추천\", \"youtubeSearchKeyword\": \"세차 방법 영상\"}','2026-01-15 15:22:34'),(57,54,'SUMMARY','{\"aiDiv\": \"gemini\", \"history\": null, \"industry\": \"carwash\", \"question\": \"세차방법\", \"isFirstChat\": true}','{\"intent\": \"HOW_TO\", \"question\": \"세차방법\", \"chatTitle\": \"세차 방법 안내\", \"productList\": null, \"shortSummary\": \"세차하는 방법을 알려드릴게요.\", \"productKeywords\": null, \"howToSearchKeyword\": \"세차 방법 알려줘\", \"productSearchKeyword\": \"\", \"youtubeSearchKeyword\": \"세차 방법 영상\"}','2026-01-15 15:27:16'),(58,54,'SUMMARY','{\"aiDiv\": \"gemini\", \"history\": [{\"role\": \"user\", \"content\": \"세차방법\"}, {\"role\": \"assistant\", \"content\": \"세차하는 방법을 알려드릴게요.\\n\\n세\\n\\n차 방법은 크게 두 가지로 나눌 수 있습니다.\\n**1. 외부 세차**\\n\\n*   **준비물:**\\n  *   카샴푸 (차량용)\\n  *   세차용 스펀지 또는 워시미트\\n  *   버킷 (2개: 하나는 카샴푸용, 다른\\n\\n하나는 헹굼용)\\n  *   고압수건 또는 드라잉 타월\\n  *   휠 클리너 (필요시)\\n  *   타이어 광택제 (필요시)\\n\\n  *   유리 세정제\\n  *   세차장 또는 물을 사용할 수 있는 공간\\n*   **세차 순서:**\\n  1.  **차량 전체 물 뿌리기:** 고압수를 이용하여\\n\\n차량 전체에 묻은 먼지와 흙을 1차적으로 제거합니다.\\n  2.  **휠 세척:** 휠 클리너를 사용하여 휠의 오염물을 불린 후, 휠 브\\n\\n러시로 문질러 닦습니다.\\n  3.  **카샴푸 거품 만들기:** 버킷에 카샴푸를 넣고 물을 채워 풍성한 거품을 만듭니다.\\n  4\\n\\n.  **차량 도장면 세척:** 세차용 스펀지나 워시미트에 카샴푸 거품을 묻혀 위에서부터 아래로 부드럽게 닦아냅니다. 이때,\\n\\n한 번 닦을 때마다 깨끗한 물로 스펀지/미트를 헹궈 먼지가 도장면에 긁힘을 일으키지 않도록 주의합니다. (2버킷 세차법 활용)\\n  5.  \\n\\n**차량 전체 헹굼:** 깨끗한 물로 차량 전체에 묻은 카샴푸 거품을 완전히 헹궈냅니다.\\n  6.  **물기 제거:** 고압수건이나 드라잉 타월을\\n\\n사용하여 차량의 물기를 꼼꼼하게 닦아냅니다. 물방울이 남지 않도록 주의해야 얼룩을 방지할 수 있습니다.\\n  7.  **유리 세정:** 유리 세정제를\\n\\n사용하여 앞유리, 옆유리, 뒷유리의 얼룩을 깨끗하게 닦아냅니다.\\n  8.  **타이어 광택 (선택 사항):** 타이어 광택제를 사용하여 타이어\\n\\n에 윤기를 더합니다.\\n**2. 내부 세차**\\n*   **준비물:**\\n  *   진공청소기 (차량용 또는 가정용)\\n  *   극세사 타월\\n  *   실\\n\\n내 세정제 (대시보드, 가죽 시트 등 재질에 맞는 제품 사용)\\n  *   물티슈 (간단한 얼룩 제거용)\\n  *   먼지떨이 또는 부\\n\\n드러운 솔\\n*   **세차 순서:**\\n  1.  **바닥 매트 청소:** 바닥 매트를 꺼내 먼지를 털어내고, 필요시 물로 세척 후 완전히\\n\\n말립니다.\\n  2.  **차량 내부 진공 청소:** 진공청소기를 사용하여 바닥, 시트 틈새, 트렁크 등 구석구석 먼지와 이물질을 제거합니다.\\n\\n  3.  **대시보드 및 내장재 닦기:** 실내 세정제를 극세사 타월에 묻혀 대시보드, 도어 패널 등 플라스틱 및 가죽 부분을\\n\\n닦아줍니다. 직접 분사하는 것보다 타월에 묻혀 사용하는 것이 얼룩 방지에 좋습니다.\\n  4.  **시트 청소:** 가죽 시트의 경우 가죽 전용 클리너를,\\n\\n패브릭 시트의 경우 패브릭 클리너를 사용하여 얼룩을 제거합니다.\\n  5.  **유리 내부 청소:** 유리 세정제를 사용하여 차량 내부 유리창을 깨끗하게 닦습니다.\\n\\n  6.  **송풍구 및 틈새 청소:** 먼지떨이나 부드러운 솔을 사용하여 송풍구 틈새의 먼지를 제거합니다.\\n**추가 팁:**\\n*   **\\n\\n그늘에서 세차하기:** 직사광선 아래에서 세차하면 물기가 너무 빨리 말라 얼룩이 생기기 쉽습니다.\\n*   **세차 용품은 전용 제품 사용:** 차량 도장면\\n\\n이나 내장재 손상을 방지하기 위해 차량 전용 세차 용품을 사용하는 것이 좋습니다.\\n*   **정기적인 세차:** 차량을 깨끗하게 유지하는 것은 외관을 보기 좋게 할 뿐만 아니라 차량\\n\\n의 수명을 연장하는 데도 도움이 됩니다.\\n궁금한 점이 있다면 언제든지 다시 질문해주세요.\\n\\n\"}], \"industry\": \"carwash\", \"question\": \"세차방법\", \"isFirstChat\": false}','{\"intent\": \"HOW_TO\", \"question\": \"세차방법\", \"chatTitle\": \"세차 방법 안내\", \"productList\": null, \"shortSummary\": \"세차하는 방법에 대한 안내입니다.\", \"productKeywords\": null, \"howToSearchKeyword\": \"세차 방법\", \"productSearchKeyword\": \"세차 용품 추천\", \"youtubeSearchKeyword\": \"세차 방법 영상\"}','2026-01-15 15:28:10'),(59,54,'SUMMARY','{\"aiDiv\": \"gemini\", \"history\": [{\"role\": \"assistant\", \"content\": \"세차하는 방법을 알려드릴게요.\\n\\n세\\n\\n차 방법은 크게 두 가지로 나눌 수 있습니다.\\n**1. 외부 세차**\\n\\n*   **준비물:**\\n  *   카샴푸 (차량용)\\n  *   세차용 스펀지 또는 워시미트\\n  *   버킷 (2개: 하나는 카샴푸용, 다른\\n\\n하나는 헹굼용)\\n  *   고압수건 또는 드라잉 타월\\n  *   휠 클리너 (필요시)\\n  *   타이어 광택제 (필요시)\\n\\n  *   유리 세정제\\n  *   세차장 또는 물을 사용할 수 있는 공간\\n*   **세차 순서:**\\n  1.  **차량 전체 물 뿌리기:** 고압수를 이용하여\\n\\n차량 전체에 묻은 먼지와 흙을 1차적으로 제거합니다.\\n  2.  **휠 세척:** 휠 클리너를 사용하여 휠의 오염물을 불린 후, 휠 브\\n\\n러시로 문질러 닦습니다.\\n  3.  **카샴푸 거품 만들기:** 버킷에 카샴푸를 넣고 물을 채워 풍성한 거품을 만듭니다.\\n  4\\n\\n.  **차량 도장면 세척:** 세차용 스펀지나 워시미트에 카샴푸 거품을 묻혀 위에서부터 아래로 부드럽게 닦아냅니다. 이때,\\n\\n한 번 닦을 때마다 깨끗한 물로 스펀지/미트를 헹궈 먼지가 도장면에 긁힘을 일으키지 않도록 주의합니다. (2버킷 세차법 활용)\\n  5.  \\n\\n**차량 전체 헹굼:** 깨끗한 물로 차량 전체에 묻은 카샴푸 거품을 완전히 헹궈냅니다.\\n  6.  **물기 제거:** 고압수건이나 드라잉 타월을\\n\\n사용하여 차량의 물기를 꼼꼼하게 닦아냅니다. 물방울이 남지 않도록 주의해야 얼룩을 방지할 수 있습니다.\\n  7.  **유리 세정:** 유리 세정제를\\n\\n사용하여 앞유리, 옆유리, 뒷유리의 얼룩을 깨끗하게 닦아냅니다.\\n  8.  **타이어 광택 (선택 사항):** 타이어 광택제를 사용하여 타이어\\n\\n에 윤기를 더합니다.\\n**2. 내부 세차**\\n*   **준비물:**\\n  *   진공청소기 (차량용 또는 가정용)\\n  *   극세사 타월\\n  *   실\\n\\n내 세정제 (대시보드, 가죽 시트 등 재질에 맞는 제품 사용)\\n  *   물티슈 (간단한 얼룩 제거용)\\n  *   먼지떨이 또는 부\\n\\n드러운 솔\\n*   **세차 순서:**\\n  1.  **바닥 매트 청소:** 바닥 매트를 꺼내 먼지를 털어내고, 필요시 물로 세척 후 완전히\\n\\n말립니다.\\n  2.  **차량 내부 진공 청소:** 진공청소기를 사용하여 바닥, 시트 틈새, 트렁크 등 구석구석 먼지와 이물질을 제거합니다.\\n\\n  3.  **대시보드 및 내장재 닦기:** 실내 세정제를 극세사 타월에 묻혀 대시보드, 도어 패널 등 플라스틱 및 가죽 부분을\\n\\n닦아줍니다. 직접 분사하는 것보다 타월에 묻혀 사용하는 것이 얼룩 방지에 좋습니다.\\n  4.  **시트 청소:** 가죽 시트의 경우 가죽 전용 클리너를,\\n\\n패브릭 시트의 경우 패브릭 클리너를 사용하여 얼룩을 제거합니다.\\n  5.  **유리 내부 청소:** 유리 세정제를 사용하여 차량 내부 유리창을 깨끗하게 닦습니다.\\n\\n  6.  **송풍구 및 틈새 청소:** 먼지떨이나 부드러운 솔을 사용하여 송풍구 틈새의 먼지를 제거합니다.\\n**추가 팁:**\\n*   **\\n\\n그늘에서 세차하기:** 직사광선 아래에서 세차하면 물기가 너무 빨리 말라 얼룩이 생기기 쉽습니다.\\n*   **세차 용품은 전용 제품 사용:** 차량 도장면\\n\\n이나 내장재 손상을 방지하기 위해 차량 전용 세차 용품을 사용하는 것이 좋습니다.\\n*   **정기적인 세차:** 차량을 깨끗하게 유지하는 것은 외관을 보기 좋게 할 뿐만 아니라 차량\\n\\n의 수명을 연장하는 데도 도움이 됩니다.\\n궁금한 점이 있다면 언제든지 다시 질문해주세요.\\n\\n\"}, {\"role\": \"user\", \"content\": \"세차방법\"}], \"industry\": \"carwash\", \"question\": \"세차방법\", \"isFirstChat\": false}','{\"intent\": \"HOW_TO\", \"question\": \"세차방법\", \"chatTitle\": \"세차 방법 안내\", \"productList\": null, \"shortSummary\": \"세차하는 방법을 알려드릴게요.\", \"productKeywords\": null, \"howToSearchKeyword\": \"세차 방법\", \"productSearchKeyword\": \"\", \"youtubeSearchKeyword\": \"세차 방법\"}','2026-01-15 15:29:28'),(60,54,'SUMMARY','{\"aiDiv\": \"gemini\", \"history\": [{\"role\": \"user\", \"content\": \"세차방법\"}, {\"role\": \"user\", \"content\": \"세차방법\"}], \"industry\": \"carwash\", \"question\": \"세차방법\", \"isFirstChat\": false}','{\"intent\": \"HOW_TO\", \"question\": \"세차방법\", \"chatTitle\": \"세차 방법 안내\", \"productList\": null, \"shortSummary\": \"세차 방법에 대한 정보를 알려드립니다.\", \"productKeywords\": null, \"howToSearchKeyword\": \"세차 방법\", \"productSearchKeyword\": \"\", \"youtubeSearchKeyword\": \"세차 방법 영상\"}','2026-01-15 15:30:12'),(61,55,'SUMMARY','{\"aiDiv\": \"gemini\", \"history\": null, \"industry\": \"carwash\", \"question\": \"세차방법\", \"isFirstChat\": true}','{\"intent\": \"HOW_TO\", \"question\": \"세차방법\", \"chatTitle\": \"세차 방법 안내\", \"productList\": null, \"shortSummary\": \"세차하는 방법을 알려드릴게요.\", \"productKeywords\": null, \"howToSearchKeyword\": \"세차 방법 알려줘\", \"productSearchKeyword\": \"\", \"youtubeSearchKeyword\": \"세차 방법 영상\"}','2026-01-15 15:56:07'),(62,55,'SUMMARY','{\"aiDiv\": \"gemini\", \"history\": [{\"role\": \"user\", \"content\": \"세차방법\"}], \"industry\": \"carwash\", \"question\": \"세차방법\", \"isFirstChat\": false}','{\"intent\": \"HOW_TO\", \"question\": \"세차방법\", \"chatTitle\": \"세차 방법 안내\", \"productList\": null, \"shortSummary\": \"세차하는 방법을 알려드릴게요.\", \"productKeywords\": null, \"howToSearchKeyword\": \"세차 방법 자세히 알려줘\", \"productSearchKeyword\": \"\", \"youtubeSearchKeyword\": \"세차 방법 영상\"}','2026-01-15 15:57:55'),(63,55,'SUMMARY','{\"aiDiv\": \"gemini\", \"history\": [{\"role\": \"user\", \"content\": \"세차방법\"}, {\"role\": \"assistant\", \"content\": \"차량 세차는 사전 준비, 휠/타이어 세척, 프리워시, 본 세차, 드라잉, 유리 세정\\n\\n, 마무리 단계로 진행됩니다. 스크래치 방지를 위해 2버킷 세차 및 부드러운 도구 사용이 중요하며, 모든 과정에서 충분한 윤활과 꼼꼼한 헹굼 및\\n\\n건조가 필수적입니다.\"}], \"industry\": \"carwash\", \"question\": \"세차방법\", \"isFirstChat\": false}','{\"intent\": \"HOW_TO\", \"question\": \"세차방법\", \"chatTitle\": \"세차 방법 안내\", \"productList\": null, \"shortSummary\": \"세차하는 방법을 알려드립니다.\", \"productKeywords\": null, \"howToSearchKeyword\": \"세차 방법\", \"productSearchKeyword\": \"세차 용품 추천\", \"youtubeSearchKeyword\": \"세차 방법 영상\"}','2026-01-15 15:58:24'),(64,55,'SUMMARY','{\"aiDiv\": \"gemini\", \"history\": [{\"role\": \"user\", \"content\": \"세차방법\"}, {\"role\": \"assistant\", \"content\": \"차\\n\\n량 세차는 준비, 휠/타이어 세척, 프리워시, 본 세차, 드라잉, 유리 세정, 마무리 단계로 구성됩니다. 스크래치 방지를 위해 2버킷 세\\n\\n차, 부드러운 도구 사용, 충분한 윤활이 중요합니다. 직사광선을 피하고 올바른 순서와 케미컬 사용으로 차량 손상을 최소화하며 최상의 외관을 유지합니다\\n\\n.\"}], \"industry\": \"carwash\", \"question\": \"세차방법\", \"isFirstChat\": false}','{\"intent\": \"HOW_TO\", \"question\": \"세차방법\", \"chatTitle\": \"세차 방법 안내\", \"productList\": null, \"shortSummary\": \"세차하는 방법을 알려드립니다.\", \"productKeywords\": null, \"howToSearchKeyword\": \"세차 방법\", \"productSearchKeyword\": \"세차 용품 추천\", \"youtubeSearchKeyword\": \"세차 방법 영상\"}','2026-01-15 15:58:46'),(65,56,'SUMMARY','{\"aiDiv\": \"gemini\", \"history\": null, \"industry\": \"carwash\", \"question\": \"세차방법\", \"isFirstChat\": true}','{\"intent\": \"HOW_TO\", \"question\": \"세차방법\", \"chatTitle\": \"세차 방법 안내\", \"productList\": null, \"shortSummary\": \"세차하는 방법을 알려드릴게요.\", \"productKeywords\": null, \"howToSearchKeyword\": \"세차 방법 알려줘\", \"productSearchKeyword\": \"\", \"youtubeSearchKeyword\": \"세차 방법 영상\"}','2026-01-15 16:03:35'),(66,57,'SUMMARY','{\"aiDiv\": \"gemini\", \"history\": null, \"industry\": \"carwash\", \"question\": \"세차방법\", \"isFirstChat\": true}','{\"intent\": \"HOW_TO\", \"question\": \"세차방법\", \"chatTitle\": \"세차 방법 안내\", \"productList\": null, \"shortSummary\": \"세차하는 방법을 알려드릴게요.\", \"productKeywords\": null, \"howToSearchKeyword\": \"세차 방법 알려줘\", \"productSearchKeyword\": \"\", \"youtubeSearchKeyword\": \"세차 방법 영상\"}','2026-01-15 16:07:19'),(67,58,'SUMMARY','{\"aiDiv\": \"gemini\", \"history\": null, \"industry\": \"carwash\", \"question\": \"세차방법\", \"isFirstChat\": true}','{\"intent\": \"HOW_TO\", \"question\": \"세차방법\", \"chatTitle\": \"세차 방법 안내\", \"productList\": null, \"shortSummary\": \"세차하는 방법을 알려드릴게요.\", \"productKeywords\": null, \"howToSearchKeyword\": \"세차 방법 알려줘\", \"productSearchKeyword\": \"\", \"youtubeSearchKeyword\": \"세차 방법 영상\"}','2026-01-15 16:15:10'),(68,58,'SUMMARY','{\"aiDiv\": \"gemini\", \"history\": [{\"role\": \"user\", \"content\": \"세차방법\"}, {\"role\": \"assistant\", \"content\": \"차\\n\\n량 세차는 예비 세차, 본 세차, 마무리 단계로 구성됩니다. 예비 세차에서는 고압수와 폼건으로 1차 오염물을 제거하고, 본 세차에서는 워싱 미트와 버\\n\\n킷 테크닉을 활용하여 도장면에 흠집 없이 오염물을 닦아냅니다. 마무리 단계에서는 드라잉 타월로 건조하고, 필요에 따라 유리 세정, 타이어 광택, \\n\\n왁스 또는 유리막 코팅 등으로 차량을 보호하고 광택을 더합니다. 3pH 세차는 오염물 종류에 따라 알칼리, 산성, 중성 세제를 순차적으로 사용하는 고급 세차 방법입니다.\"}], \"industry\": \"carwash\", \"question\": \"더 자세히  알려줘\", \"isFirstChat\": false}','{\"intent\": \"HOW_TO\", \"question\": \"더 자세히 알려줘\", \"chatTitle\": \"세차 방법 상세 안내\", \"productList\": null, \"shortSummary\": \"세차 방법에 대한 상세 정보를 알려드립니다.\", \"productKeywords\": null, \"howToSearchKeyword\": \"세차 방법 상세 설명\", \"productSearchKeyword\": \"\", \"youtubeSearchKeyword\": \"세차 방법 상세 영상\"}','2026-01-15 16:16:01'),(69,61,'SUMMARY','{\"aiDiv\": \"gemini\", \"history\": null, \"industry\": \"carwash\", \"question\": \"3ph머야\", \"isFirstChat\": true}','{\"intent\": \"YOUTUBE\", \"question\": \"3ph머야\", \"chatTitle\": \"3PH 세차 방법\", \"productList\": null, \"shortSummary\": \"3PH 세차 방법에 대한 영상 정보를 찾아드릴게요.\", \"productKeywords\": null, \"howToSearchKeyword\": \"\", \"productSearchKeyword\": \"\", \"youtubeSearchKeyword\": \"3PH 세차 방법\"}','2026-01-15 16:35:12'),(70,61,'SUMMARY','{\"aiDiv\": \"gemini\", \"history\": [{\"role\": \"user\", \"content\": \"3ph머야\"}, {\"role\": \"assistant\", \"content\": \"3PH 세차 방법에 대한 영상 정보를 찾아드릴게요.\\n\\n? 추천 유튜브 영상:\\n\\n• 3pH 세차 하시는 분들은 꼭 보세요!!! (※ 완벽한 세차 방법)\\n  https://www.youtube.com/watch?v=oXtCR6-tjTM\\n\\n• 장마철 이후에 하는 3pH 세차 방법\\n  https://www.youtube.com/watch?v=FwVqqrPRzxI\\n\\n• 묵은때 제거에 탁월! 3pH 세차 방법\\n  https://www.youtube.com/watch?v=E8CD_tnhWDg\\n\\n• 평생 모르고 안 하면 후회할 3pH 세차 방법\\n  https://www.youtube.com/watch?v=7OaQqZQEzg8\\n\\n• 셀프세차 초보자를 위한 3ph 세차 방법 외우지 말고 이해하세요! 알칼리 산성 중성 프리워시 알고 쓰자!\\n  https://www.youtube.com/watch?v=aBQ2FtTXjNA\\n\\n• 전세계가 3pH 세차 방법으로 바뀌어가는 이유\\n  https://www.youtube.com/watch?v=TjMNupOI8L4\\n\\n• 3ph 세차 방법 이렇게 이해하면 쉽습니다 #셀프세차 #세차 #세차용품\\n  https://www.youtube.com/watch?v=-g138CLT-NA\\n\\n• 비 맞은 차를 위한 완벽한 세차 방법 3pH 세차의 모든 것 틀어놓고 따라만 하세요\\n  https://www.youtube.com/watch?v=fk7JUgd9is0\\n\\n• 가장 완벽하게 세차하는 방법, 3pH세차\\n  https://www.youtube.com/watch?v=esOGzFrfXn8\\n\\n• 초보자도 쉽게 할 수 있는 3PH 세차 쏘렌토로 해봤습니다.\\n  https://www.youtube.com/watch?v=wua3rSLioAg\\n\\n• 3ph 세차! 묵은 때 셀프세차는 이렇게 하면 날아갑니다!\\n  https://www.youtube.com/watch?v=3jiWaY_rgLg\\n\\n• 3PH 세차 라고 들어 보셧나요? 겨울철 가장 안전한 세차방법(feat.마프라)\\n  https://www.youtube.com/watch?v=npC2ShfOA-o\\n\\n• 세차 고수들의 3pH 세차 꿀팁? | 디테일링 위드 미 시즌4\\n  https://www.youtube.com/watch?v=LXGy9bl6V6A\\n\\n• 여름철 3ph 세차법으로 내 차 깔끔하게 관리하자!! #3ph세차 #세차 #세차브이로그 #셀프세차\\n  https://www.youtube.com/watch?v=TE79i7mzaPE\\n\\n• 일반인은 모르는 3pH 세차 방법이 필수인 이유 !!\\n  https://www.youtube.com/watch?v=5Hr3ZCEj5Uk\\n\\n• 겨울철 세차방법 feat. 3pH\\n  https://www.youtube.com/watch?v=vdml514y4xo\\n\\n• 3PH 프리워시 매번 무조건 해줘야 되는건가요? / 셀프세차 초보자분들이 제일 많이 물어보는 알칼리성 , 산성 , 중성 3PH 세차방법!\\n  https://www.youtube.com/watch?v=pXhzOyUF8d8\\n\\n• 세차 이렇게 해보세요 #라보코스메티카 3ph\\n  https://www.youtube.com/watch?v=HOgGFAiFucY\\n\\n• 3ph세차 프리워시제 추천!\\n  https://www.youtube.com/watch?v=r_g_l7Z6b5g\\n\\n• 세정력 하나만 보고 고른 3ph 세차 꿀조합\\n  https://www.youtube.com/watch?v=3Pr1dNOgyNw\\n\\n• 3pH 효과를 극대화하는 가장 완벽한 방법을 소개합니다\\n  https://www.youtube.com/watch?v=6cNWME8qw74\\n\\n• 폼랜스 사용법 딱 4가지만 기억하세요!  원액 폼랜스로 3ph 세차하기\\n  https://www.youtube.com/watch?v=f87HBLlM3aM\\n\\n• 3pH 세차 방법이 탄생된 이유\\n  https://www.youtube.com/watch?v=3vbldgWgkq4\\n\\n• 셀프세차 순서 알려드릴께요\\n  https://www.youtube.com/watch?v=2YUKiVLbo2s\\n\\n• 셀프세차 순서와 방법! 1시간으로 끝내기\\n  https://www.youtube.com/watch?v=zOxmXByZTOc\"}], \"industry\": \"carwash\", \"question\": \"세차방법알려줘\", \"isFirstChat\": false}','{\"intent\": \"HOW_TO\", \"question\": \"세차방법알려줘\", \"chatTitle\": \"세차 방법 안내\", \"productList\": null, \"shortSummary\": \"세차 방법을 알려드릴게요.\", \"productKeywords\": null, \"howToSearchKeyword\": \"세차 방법 알려줘\", \"productSearchKeyword\": \"세차 용품 추천\", \"youtubeSearchKeyword\": \"세차 방법\"}','2026-01-15 16:36:24'),(71,62,'SUMMARY','{\"aiDiv\": \"gemini\", \"history\": null, \"industry\": \"carwash\", \"question\": \"3ph  머야\", \"isFirstChat\": true}','{\"intent\": \"YOUTUBE\", \"question\": \"3ph 머야\", \"chatTitle\": \"3PH 세차 방법\", \"productList\": null, \"shortSummary\": \"3PH 세차 방법 설명\", \"productKeywords\": null, \"howToSearchKeyword\": \"\", \"productSearchKeyword\": \"\", \"youtubeSearchKeyword\": \"3PH 세차 방법\"}','2026-01-15 16:45:59'),(72,63,'SUMMARY','{\"aiDiv\": \"gemini\", \"history\": null, \"industry\": \"carwash\", \"question\": \"3ph 머야\", \"isFirstChat\": true}','{\"intent\": \"HOW_TO\", \"question\": \"3ph 머야\", \"chatTitle\": \"3PH 세차 방법 문의\", \"productList\": null, \"shortSummary\": \"3PH 세차 방법 문의\", \"productKeywords\": null, \"howToSearchKeyword\": \"세차 3ph 방법이란 무엇인가요?\", \"productSearchKeyword\": \"세차 3ph 관련 용품\", \"youtubeSearchKeyword\": \"세차 3ph 방법 영상\"}','2026-01-15 16:51:33'),(73,63,'SUMMARY','{\"aiDiv\": \"gemini\", \"history\": [{\"role\": \"user\", \"content\": \"3ph 머야\"}, {\"role\": \"assistant\", \"content\": \"세차 3pH 방법은 차량 오염물을 효과\\n\\n적으로 제거하기 위해 알칼리성, 산성, 중성 세제를 순차적으로 사용하는 과학적인 세차 공법입니다. 알칼리 세제는 유기 오염물(먼지, 유분 등)을, 산성 세제\\n\\n는 무기 오염물(철분, 석회질 등)을 제거하며, 마지막 중성 세제로 안전하게 마무리하여 차량 손상을 최소화하고 최상의 세차 결과를 얻습니다.\"}], \"industry\": \"carwash\", \"question\": \"관련 영상 찾아줘\", \"isFirstChat\": false}','{\"intent\": \"YOUTUBE\", \"question\": \"관련 영상 찾아줘\", \"chatTitle\": null, \"productList\": null, \"shortSummary\": \"세차 관련 영상을 찾아드립니다.\", \"productKeywords\": null, \"howToSearchKeyword\": \"\", \"productSearchKeyword\": \"\", \"youtubeSearchKeyword\": \"세차 관련 영상\"}','2026-01-15 16:52:00'),(74,64,'SUMMARY','{\"aiDiv\": \"gemini\", \"history\": null, \"industry\": \"carwash\", \"question\": \"3ph가 머야\", \"isFirstChat\": true}','{\"intent\": \"HOW_TO\", \"question\": \"3ph가 머야\", \"chatTitle\": \"3PH 세차 방법 문의\", \"productList\": null, \"shortSummary\": \"3PH 세차 방법 문의\", \"productKeywords\": null, \"howToSearchKeyword\": \"3ph 세차 방법이란 무엇인가요?\", \"productSearchKeyword\": \"3ph 세차 용품 추천\", \"youtubeSearchKeyword\": \"3ph 세차 방법 영상\"}','2026-01-15 16:54:58'),(75,64,'SUMMARY','{\"aiDiv\": \"gemini\", \"history\": [{\"role\": \"user\", \"content\": \"3ph가 머야\"}, {\"role\": \"assistant\", \"content\": \"3pH 세차는 알칼리, 산성, 중성 세정제를 순차적으로 사용하여 차량의 유분, 무기 오염물, 잔여\\n\\n물 등을 효과적으로 제거하는 공법입니다. 알칼리로 유분 제거, 산성으로 무기 오염물 제거, 중성으로 잔여물 제거 및 마무리를 하며, 도장면 보호와 깊은 세정을 목표\\n\\n로 합니다.\"}], \"industry\": \"carwash\", \"question\": \"관련 영상 찾아줘\", \"isFirstChat\": false}','{\"intent\": \"YOUTUBE\", \"question\": \"관련 영상 찾아줘\", \"chatTitle\": null, \"productList\": null, \"shortSummary\": \"3PH 세차 방법 영상 검색\", \"productKeywords\": null, \"howToSearchKeyword\": \"\", \"productSearchKeyword\": \"\", \"youtubeSearchKeyword\": \"3PH 세차 방법 영상\"}','2026-01-15 16:55:19'),(76,65,'SUMMARY','{\"aiDiv\": \"gemini\", \"history\": null, \"industry\": \"carwash\", \"question\": \"세차방법 알려줘\", \"isFirstChat\": true}','{\"intent\": \"HOW_TO\", \"question\": \"세차방법 알려줘\", \"chatTitle\": \"세차 방법 안내\", \"productList\": null, \"shortSummary\": \"세차하는 방법을 알려드립니다.\", \"productKeywords\": null, \"howToSearchKeyword\": \"세차 방법 상세 안내\", \"productSearchKeyword\": \"세차 용품 추천\", \"youtubeSearchKeyword\": \"세차 방법 영상\"}','2026-01-16 09:34:58'),(77,65,'SUMMARY','{\"aiDiv\": \"gemini\", \"history\": [{\"role\": \"user\", \"content\": \"세차방법 알려줘\"}, {\"role\": \"assistant\", \"content\": \"세차하는 방법을 알려드립니다.\\n\\n세\\n\\n차는 단순히 물과 비눗물로 차를 닦는 행위를 넘어, 차량\\n\\n의 외관을 보호하고 가치를 유지하는 중요한 관리 과정입니다. 올바른 세차 방법을 숙지하고 실천한다면, 차량 도장면의 손상을 최소화하고 최상의 컨디션을 유지할 수 있습니다.\\n\\n**1. 세차 전 준비 단계**\\n*   **세차 용품 준비:**\\n  *   **카샴푸:** 차량 도장면에 안전한 중성 또는 약알칼리성 카샴푸를 준비\\n\\n합니다.\\n  *   **세차 버킷:** 카샴푸와 물을 섞을 용도로 2개 이상 준비하는 것이 좋습니다. 하나는 카샴푸 물용, 다른 하나는 헹굼용으로 사용하여\\n\\n오염물이 다시 도장면에 묻는 것을 방지합니다.\\n  *   **워시 미트 또는 세차 타월:** 부드러운 극세사 재질의 워시 미트나 세차 타월을\\n\\n사용하여 도장면 흠집을 예방합니다.\\n  *   **휠/타이어 클리너 및 브러쉬:** 휠과 타이어의 찌든 때를 제거하기 위한 전용 클리너와 브러쉬\\n\\n를 준비합니다.\\n  *   **드라잉 타월:** 물기를 빠르게 흡수하는 두껍고 부드러운 극세사 드라잉 타월을 사용합니다.\\n  *   **유리 세\\n\\n정제 및 유리 전용 타월:** 차량 유리의 얼룩을 제거하고 투명도를 높이기 위한 제품입니다.\\n  *   **타이어 광택제 (선택 사항):** 타이어에 윤기를 더하고 보호\\n\\n하는 역할을 합니다.\\n*   **세차 장소 선정:**\\n  *   **그늘진 곳:** 직사광선은 세정제가 도장면에서 너무 빨리 말라 얼룩을 남길 수 있으므로 피\\n\\n해야 합니다.\\n  *   **환기:** 실내 세차장의 경우 환기가 잘 되는 곳을 선택합니다.\\n*   **차량 사전 점검:**\\n  *   차량 외부의 큰 이물질(나\\n\\n뭇잎, 흙덩이 등)은 미리 제거합니다.\\n**2. 세차 단계별 상세 안내**\\n*   **1단계: 프리워시 (Pre-wash)**\\n  *   **목적:** 도\\n\\n장면에 직접적인 접촉 없이 표면의 흙, 먼지, 유기물 등 1차적인 오염물을 불려 제거합니다. 이는 본 세차 시 도장면 흠집 발생 가능성을 크게 줄여\\n\\n줍니다.\\n  *   **방법:**\\n      *   차량 전체에 고압수를 뿌려 큰 먼지와 흙을 1차적으로 제거합니다.\\n      *   친수성 프리워시 제품을 차량\\n\\n하부부터 상부 순서로 뿌립니다. (제품 사용 설명서를 따르세요.)\\n      *   약 1~2분간 기다려 오염물이 불어나도록 합니다. (제품이 마르지 않도록 주의\\n\\n합니다.)\\n      *   다시 한번 고압수로 프리워시 잔여물과 불어난 오염물을 깨끗하게 헹궈냅니다.\\n      *   **주의:** 산성 프리워시의 경우, \\n\\n휠이나 타이어에 직접 분사 시 변색이나 손상을 유발할 수 있으므로 주의가 필요합니다. 휠, 타이어는 별도의 전용 클리너로 세척하는 것이 좋습니다.\\n*   **2단계:\\n\\n휠 & 타이어 세척**\\n  *   **목적:** 브레이크 분진, 타르, 도로 오염물 등 휠과 타이어에 특화된 강한 오염물을 제거합니다.\\n  *   **\\n\\n방법:**\\n      *   휠/타이어 전용 클리너를 휠과 타이어에 분사합니다.\\n      *   휠 브러쉬와 타이어 브러쉬를 사용하여 휠 틈새, 타이어 표\\n\\n면의 오염물을 문질러 제거합니다.\\n      *   고압수로 깨끗하게 헹궈냅니다.\\n*   **3단계: 본 세차 (Two-bucket method)**\\n  *   **\\n\\n목적:** 도장면의 찌든 때, 유분, 오염물 등을 카샴푸를 이용하여 안전하게 제거합니다.\\n  *   **방법:**\\n      *   **투 버킷 세차법:**\\n\\n          *   버킷 1: 카샴푸와 물을 희석하여 준비합니다. (권장 희석 비율은 제품 설명서 참조)\\n          *   버킷 2: 깨끗한 물만 준비합니다\\n\\n.\\n      *   워시 미트(또는 세차 타월)를 카샴푸 물에 적셔 차량의 지붕부터 시작하여 상부에서 하부로, 일정한 방향으로 부드럽게 닦아\\n\\n내려갑니다.\\n      *   한 번 닦을 때마다 워시 미트를 버킷 2의 깨끗한 물에 헹궈 오염물을 제거합니다.\\n      *   다시 카샴푸 물에\\n\\n워시 미트를 적셔 다음 구역을 닦습니다. 이 과정을 반복하여 차량 전체를 세척합니다.\\n      *   **주의:** 워시 미트가 바닥에 떨어지면 즉시 깨끗한 물로\\n\\n헹구거나 새것으로 교체합니다. 바닥의 이물질이 묻은 미트는 도장면에 심각한 흠집을 유발합니다.\\n*   **4단계: 헹굼**\\n\\n  *   **목적:** 차량에 남아있는 카샴푸 잔여물과 불어난 오염물을 완전히 제거합니다.\\n  *   **방법:**\\n      *   차량의 지붕부터 시작하여 고압수로\\n\\n꼼꼼하게 헹궈냅니다.\\n      *   도어 틈새, 트렁크, 본넷 등의 틈새 부분도 신경 써서 헹궈 카샴푸 잔여물이 남지 않도록 합니다.\\n\\n*   **5단계: 물기 제거 (드라잉)**\\n  *   **목적:** 도장면에 물 얼룩(워터 스팟)이 생기는 것을 방지하고, 다음 단계인 코팅 작업\\n\\n의 효과를 높입니다.\\n  *   **방법:**\\n      *   부드럽고 흡수력이 좋은 극세사 드라잉 타월을 사용합니다.\\n      *   차량의 지붕부터 시작하여 넓\\n\\n은 면적을 덮어 물기를 흡수하듯이 닦아냅니다.\\n      *   타월을 끌지 않고, 물기를 흡수시키는 방식으로 닦는 것이 흠집 예방에 도움이 됩니다.\\n      *   \\n\\n필요하다면 드라잉 타월을 여러 번 바꿔가며 물기를 완전히 제거합니다.\\n      *   틈새나 엠블럼 주변의 물기도 에어 블로워나 드라잉 타월을 이용하여\\n\\n꼼꼼히 제거합니다.\\n*   **6단계: 유리 세척**\\n  *   **목적:** 외부 및 내부 유리의 시야를 방해하는 얼룩, 먼지, 유분 등을 제거하여\\n\\n운전 시야를 확보합니다.\\n  *   **방법:**\\n      *   유리 전용 세정제와 깨끗한 극세사 타월을 사용합니다.\\n      *   유리 세정제를 타\\n\\n월에 소량 분사한 후, 유리를 닦습니다.\\n      *   다른 깨끗한 타월로 즉시 닦아내어 얼룩이 남지 않도록 합니다.\\n      *   내부 유리는\\n\\n외부보다 유분기가 많을 수 있으므로, 좀 더 꼼꼼하게 닦아줍니다.\\n*   **7단계: 코팅 (선택 사항)**\\n  *   **목적:** 도장면을\\n\\n외부 오염으로부터 보호하고, 광택을 향상시키며, 다음 세차를 용이하게 합니다.\\n  *   **방법:**\\n      *   **물왁스:** 간편하게 사용할 수 있으며, 일\\n\\n시적인 광택과 발수 효과를 제공합니다. 드라잉 후 도장면에 분사하고 버핑하여 마무리합니다.\\n      *   **유리막 코팅제/스프레이 코팅제:** SiO\\n\\n2(이산화규소) 성분이 주원료이며, 더 강력하고 지속적인 보호 성능과 광택을 제공합니다. 제품 설명서에 따라 소량의 도포 후 버핑하는 방식으로 시공합니다. (50\\n\\nml 이하의 병 제품 또는 스프레이 형태)\\n      *   **주의:** 코팅 작업은 반드시 건조된 도장면에 시공해야 하며, 직사광선이 없는 환경에서 작업하는 것이 좋습니다.\\n*\\n\\n **8단계: 타이어 광택 (선택 사항)**\\n  *   **목적:** 타이어의 노화를 방지하고, 새 타이어와 같은 시각적 효과를 부여합니다.\\n  *   \\n\\n**방법:**\\n      *   타이어 전용 광택제를 타이어 측면에 어플리케이터를 이용하여 고르게 발라줍니다.\\n      *   과도하게 바르면 주행 중 튈 수 있으\\n\\n므로 적당량을 사용합니다.\\n**3. 세차 시 주의사항**\\n*   **세차 빈도:** 차량의 사용 환경, 주행 거리, 계절 등에 따라 다르지만, 일반적으로 2주~1개월\\n\\n에 한\\n\\n\"}], \"industry\": \"carwash\", \"question\": \"세차방법\", \"isFirstChat\": false}','{\"intent\": \"HOW_TO\", \"question\": \"세차방법\", \"chatTitle\": \"세차 방법 안내\", \"productList\": null, \"shortSummary\": \"올바른 세차 방법을 알려드립니다.\", \"productKeywords\": null, \"howToSearchKeyword\": \"올바른 세차 방법 상세 안내\", \"productSearchKeyword\": \"세차 용품 추천\", \"youtubeSearchKeyword\": \"세차 방법 영상\"}','2026-01-16 09:36:55'),(78,65,'SUMMARY','{\"aiDiv\": \"gemini\", \"history\": [{\"role\": \"user\", \"content\": \"세차방법\"}, {\"role\": \"user\", \"content\": \"세차방법\"}], \"industry\": \"carwash\", \"question\": \"세차방법\", \"isFirstChat\": false}','{\"intent\": \"HOW_TO\", \"question\": \"세차방법\", \"chatTitle\": \"세차 방법 안내\", \"productList\": null, \"shortSummary\": \"세차 방법에 대한 정보를 찾고 있습니다.\", \"productKeywords\": null, \"howToSearchKeyword\": \"세차 방법\", \"productSearchKeyword\": \"세차 용품 추천\", \"youtubeSearchKeyword\": \"세차 방법 영상\"}','2026-01-16 09:44:47'),(79,65,'SUMMARY','{\"aiDiv\": \"gemini\", \"history\": [{\"role\": \"user\", \"content\": \"세차방법\"}, {\"role\": \"user\", \"content\": \"세차방법\"}], \"industry\": \"carwash\", \"question\": \"세차방법\", \"isFirstChat\": false}','{\"intent\": \"HOW_TO\", \"question\": \"세차방법\", \"chatTitle\": \"세차 방법 안내\", \"productList\": null, \"shortSummary\": \"세차 방법에 대한 정보를 찾고 있습니다.\", \"productKeywords\": null, \"howToSearchKeyword\": \"세차 방법\", \"productSearchKeyword\": \"세차 용품 추천\", \"youtubeSearchKeyword\": \"세차 방법 영상\"}','2026-01-16 09:47:32'),(80,66,'SUMMARY','{\"aiDiv\": \"gemini\", \"history\": null, \"industry\": \"carwash\", \"question\": \"세차방법\", \"isFirstChat\": true}','{\"intent\": \"HOW_TO\", \"question\": \"세차방법\", \"chatTitle\": \"세차 방법 안내\", \"productList\": null, \"shortSummary\": \"세차하는 방법에 대한 정보를 찾고 있습니다.\", \"productKeywords\": null, \"howToSearchKeyword\": \"세차 방법\", \"productSearchKeyword\": \"세차 용품 추천\", \"youtubeSearchKeyword\": \"세차 방법 영상\"}','2026-01-16 10:01:48');
/*!40000 ALTER TABLE `ai_trace` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2026-01-16 11:50:26
-- MySQL dump 10.13  Distrib 8.0.34, for macos13 (x86_64)
--
-- Host: 127.0.0.1    Database: aidb
-- ------------------------------------------------------
-- Server version	8.0.44

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!50503 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `chat_message`
--

DROP TABLE IF EXISTS `chat_message`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `chat_message` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `chat_id` bigint unsigned NOT NULL,
  `turn_id` int unsigned NOT NULL,
  `role` varchar(16) NOT NULL,
  `intent` varchar(16) DEFAULT NULL,
  `content` text NOT NULL,
  `summary` text,
  `created_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_chat_turn_role_intent` (`chat_id`,`turn_id`,`role`,`intent`),
  KEY `idx_chat_turn` (`chat_id`,`turn_id`),
  KEY `idx_chat_created` (`chat_id`,`created_at`),
  CONSTRAINT `fk_chat_message_room` FOREIGN KEY (`chat_id`) REFERENCES `chat_room` (`chat_id`)
) ENGINE=InnoDB AUTO_INCREMENT=151 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `chat_message`
--

LOCK TABLES `chat_message` WRITE;
/*!40000 ALTER TABLE `chat_message` DISABLE KEYS */;
/*!40000 ALTER TABLE `chat_message` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2026-01-16 11:50:26
-- MySQL dump 10.13  Distrib 8.0.34, for macos13 (x86_64)
--
-- Host: 127.0.0.1    Database: aidb
-- ------------------------------------------------------
-- Server version	8.0.44

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!50503 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `chat_room`
--

DROP TABLE IF EXISTS `chat_room`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `chat_room` (
  `chat_id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `user_id` bigint unsigned NOT NULL,
  `last_turn_id` int unsigned NOT NULL DEFAULT '0',
  `title` varchar(100) DEFAULT NULL,
  `pinned` tinyint DEFAULT NULL,
  `industry` varchar(45) DEFAULT NULL,
  `created_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`chat_id`),
  KEY `idx_user_updated` (`user_id`,`updated_at` DESC)
) ENGINE=InnoDB AUTO_INCREMENT=67 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `chat_room`
--

LOCK TABLES `chat_room` WRITE;
/*!40000 ALTER TABLE `chat_room` DISABLE KEYS */;
/*!40000 ALTER TABLE `chat_room` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2026-01-16 11:50:26
-- MySQL dump 10.13  Distrib 8.0.34, for macos13 (x86_64)
--
-- Host: 127.0.0.1    Database: aidb
-- ------------------------------------------------------
-- Server version	8.0.44

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!50503 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `chat_summary`
--

DROP TABLE IF EXISTS `chat_summary`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `chat_summary` (
  `chat_id` bigint unsigned NOT NULL,
  `turn_id` int unsigned NOT NULL,
  `summary` text NOT NULL,
  `intent` varchar(16) NOT NULL,
  `how_to_search_keyword` varchar(45) DEFAULT NULL,
  `product_search_keyword` varchar(45) DEFAULT NULL,
  `youtube_search_keyword` varchar(45) DEFAULT NULL,
  `created_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`chat_id`,`turn_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `chat_summary`
--

LOCK TABLES `chat_summary` WRITE;
/*!40000 ALTER TABLE `chat_summary` DISABLE KEYS */;
/*!40000 ALTER TABLE `chat_summary` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2026-01-16 11:50:26
-- MySQL dump 10.13  Distrib 8.0.34, for macos13 (x86_64)
--
-- Host: 127.0.0.1    Database: aidb
-- ------------------------------------------------------
-- Server version	8.0.44

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!50503 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `interest`
--

DROP TABLE IF EXISTS `interest`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `interest` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `name` varchar(100) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB AUTO_INCREMENT=9 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `interest`
--

LOCK TABLES `interest` WRITE;
/*!40000 ALTER TABLE `interest` DISABLE KEYS */;
INSERT INTO `interest` VALUES (2,'강아지'),(5,'반려동물'),(1,'세차'),(6,'여행'),(7,'요리'),(8,'운동'),(4,'자동차'),(3,'캠핑');
/*!40000 ALTER TABLE `interest` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2026-01-16 11:50:26
-- MySQL dump 10.13  Distrib 8.0.34, for macos13 (x86_64)
--
-- Host: 127.0.0.1    Database: aidb
-- ------------------------------------------------------
-- Server version	8.0.44

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!50503 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `product`
--

DROP TABLE IF EXISTS `product`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `product` (
  `product_id` int NOT NULL AUTO_INCREMENT,
  `name` varchar(255) NOT NULL,
  `category` varchar(50) NOT NULL,
  `link` varchar(500) DEFAULT NULL,
  PRIMARY KEY (`product_id`)
) ENGINE=InnoDB AUTO_INCREMENT=106 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `product`
--

LOCK TABLES `product` WRITE;
/*!40000 ALTER TABLE `product` DISABLE KEYS */;
INSERT INTO `product` VALUES (1,'더클래스 갓클래스','유리막',''),(2,'파이어볼 슈터','유리막',''),(3,'루미너스 LM 세라믹','유리막',''),(4,'글라스킨 퀵 세라믹 아머','유리막',''),(5,'TAC시스템 에이쿼츠','유리막',''),(6,'간바스 그래핀 코팅제','유리막',''),(7,'나노아이코닉 엔젤','유리막',''),(8,'파이어볼 엔젤 티얼스','유리막',''),(9,'루미너스 LM그래핀','뿌리막',''),(10,'나노아이코닉 르샤인','뿌리막',''),(11,'더클래스 메탈불렛 디언데드','뿌리막',''),(12,'TAC 나노 다이아몬드 쿼츠','뿌리막',''),(13,'글론 인터미션 세라믹 플루이드','뿌리막',''),(14,'아담스 세라믹 그래핀 스프레이코팅','뿌리막',''),(15,'디아만테 티타늄 골드 퀵디테일러','뿌리막',''),(16,'카야컴퍼니 노머시 플러스','뿌리막',''),(17,'폼포나치 유리막클리너 만능 발수코팅제','뿌리막',''),(18,'카티바 유성코팅제','뿌리막',''),(19,'루미너스 LM 그래핀 스프레이 1','뿌리막',''),(20,'글론 인터미션','뿌리막',''),(21,'글라스킨 지브코트','뿌리막',''),(22,'루미너스 LM 그래핀 스프레이2','뿌리막',''),(23,'나노아이코닉 르샤인','뿌리막',''),(24,'더클래스 메탈불렛','뿌리막',''),(25,'스팽글 메테오','뿌리막',''),(26,'루나틱폴리시 루나왁스','물왁스',''),(27,'블라스크 슬릭퍼펙트13','물왁스',''),(28,'웨이크미 메이저톰','물왁스',''),(29,'카티바 시그니처','물왁스',''),(30,'루체왁스 글로하츠','물왁스',''),(31,'디테일링 프로 슈퍼비딩','퀵디테일러',''),(32,'기온쿼츠 큐어','물왁스',''),(33,'글로스매직 골드플러스','물왁스',''),(34,'더클래스 불렛 L-001','물왁스',''),(35,'소낙스 브샤디','물왁스',''),(36,'터틀왁스 HS 그래핀 플렉스','물왁스',''),(37,'터틀왁스 씰앤샤인 개선','물왁스',''),(38,'보닉스 SIO2-PRO','물왁스',''),(39,'라보코스메티카 퍼펙타 SIO2','물왁스',''),(40,'프로스태프 cc워터골드 프리미어','물왁스',''),(41,'지테크닉 마린세라믹패스트코트','물왁스',''),(42,'오토피네스 세라믹스프레이','물왁스',''),(43,'프로스태프 워터골드CC 퀵디테일러','물왁스',''),(44,'인피티니 슈퍼글로스&울트라','물왁스',''),(45,'자이몰 필드글레이즈','물왁스',''),(46,'루미너스 글로시','물왁스',''),(47,'TAC 리파인','물왁스',''),(48,'글로스브로 스피드와이프','물왁스',''),(49,'카티바 광부스터','퀵디테일러',''),(50,'듀플렉스 드래곤부스터','물왁스',''),(51,'불스원 크리스탈 코트 플러스','물왁스',''),(52,'카티바 웻왁스','물왁스',''),(53,'파이어볼 그레이스','물왁스',''),(54,'하이글로씨 퍼펙트 슬릭','물왁스',''),(55,'스팽글 시그니처','물왁스',''),(56,'루미너스 블랙 그래핀 에디션','물왁스',''),(57,'워시팩토리 발라','물왁스',''),(58,'소낙스 익스트림 세라믹 울트라 슬릭 디테일러','물왁스',''),(59,'니그린 세라믹 디테일러','물왁스',''),(60,'캄던 노블쉴드','물왁스',''),(61,'바운드서울 퀵디테일러','퀵디테일러',''),(62,'코흐케미 S002','물왁스',''),(63,'어반슬리크 슬릭디자인 퀵디','퀵디테일러',''),(64,'스위스벡스 로터스스피드','물왁스',''),(65,'카프로 리로드2.0','물왁스',''),(66,'보닉스 네이티브','물왁스',''),(67,'파이어볼 필루엣','물왁스',''),(68,'보닉스 블렌드','물왁스',''),(69,'울티마 아크릴릭','퀵디테일러',''),(70,'아담스 슬릭앤슬라이드','물왁스',''),(71,'불스원 퀵코트','물왁스',''),(72,'도깨비 A10퀵디테일러','퀵디테일러',''),(73,'불스원 딥코트','물왁스',''),(74,'보닉스 시너지 페인트','물왁스',''),(75,'카프로 엘릭서','물왁스',''),(76,'소낙스 익스트림 세라믹 스프레이','물왁스',''),(77,'불스원 루나왁스 익스트림','물왁스',''),(78,'파이어볼 쇼카 듀크','물왁스',''),(79,'볼라솔루션 P17 세라믹','물왁스',''),(80,'오토그루밍 듀라블코트','물왁스',''),(81,'P&S 디펜더 SIO2 프로텍턴트','물왁스',''),(82,'기온쿼츠 세라믹','물왁스',''),(83,'만월케미컬 NO.1왁스','물왁스',''),(84,'AD 세라믹 쉴드 리프레쉬','물왁스',''),(85,'SOFT99 레인드롭 바주카','물왁스',''),(86,'인피티니 시너지 퀵디테일러','퀵디테일러',''),(87,'스팽글 시크릿','퀵디테일러',''),(88,'폴리쉬엔젤 래피드왁스','물왁스',''),(89,'원스텝미러글레이즈','물왁스',''),(90,'나가라워시 플라즈마 알파','물왁스',''),(91,'하이퍼쉴드 퀵코트 블랙','물왁스',''),(92,'케미컬가이 하이드로 차지 플러스','물왁스',''),(93,'아크바리아 레펠','물왁스',''),(94,'간바스 인퓨즈','물왁스',''),(95,'아크바리아 나제나','물왁스',''),(96,'핑크다이아 하이퀄리티다이아코트','물왁스',''),(97,'루미너스 블랙 다이아몬드','물왁스',''),(98,'코팅팜 알파가드','물왁스',''),(99,'바운드서울 식스센스','물왁스',''),(100,'볼라솔루션 Z17','물왁스',''),(101,'우로보로스 2D 레이어링 BN 퀵디','물왁스',''),(102,'블라스크 12 그래핀워터','물왁스',''),(103,'아트워시 프리다코트','물왁스',''),(104,'코팅팩토리 워터글래스','물왁스',''),(105,'스파샨 슈팅잭슨','물왁스','');
/*!40000 ALTER TABLE `product` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2026-01-16 11:50:26
-- MySQL dump 10.13  Distrib 8.0.34, for macos13 (x86_64)
--
-- Host: 127.0.0.1    Database: aidb
-- ------------------------------------------------------
-- Server version	8.0.44

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!50503 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `product_score`
--

DROP TABLE IF EXISTS `product_score`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `product_score` (
  `score_id` int NOT NULL AUTO_INCREMENT,
  `product_id` int NOT NULL,
  `workability` int DEFAULT NULL,
  `slick` int DEFAULT NULL,
  `chemical_resistance` int DEFAULT NULL,
  `sheeting` int DEFAULT NULL,
  `color` int DEFAULT NULL,
  `dust` int DEFAULT NULL,
  `water_repellency` int DEFAULT NULL,
  `durability` int DEFAULT NULL,
  `price` int DEFAULT NULL,
  `total` int DEFAULT NULL,
  PRIMARY KEY (`score_id`),
  KEY `product_id` (`product_id`),
  CONSTRAINT `product_score_ibfk_1` FOREIGN KEY (`product_id`) REFERENCES `product` (`product_id`)
) ENGINE=InnoDB AUTO_INCREMENT=106 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `product_score`
--

LOCK TABLES `product_score` WRITE;
/*!40000 ALTER TABLE `product_score` DISABLE KEYS */;
INSERT INTO `product_score` VALUES (1,1,8,8,9,7,8,9,7,8,9,61),(2,2,3,9,9,8,10,5,8,9,7,66),(3,3,9,7,4,7,6,7,7,6,8,57),(4,4,7,4,9,7,8,8,6,6,2,53),(5,5,9,3,2,7,6,7,8,8,9,50),(6,6,5,2,5,8,5,7,5,6,10,48),(7,7,8,5,4,3,5,6,6,5,9,41),(8,8,6,6,7,5,4,4,7,6,2,42),(9,9,6,7,9,8,8,7,6,9,8,68),(10,10,9,9,6,9,5,3,8,6,8,63),(11,11,6,7,8,6,5,5,8,8,8,53),(12,12,7,8,4,7,5,4,8,6,8,49),(13,13,6,9,6,9,9,6,7,7,8,57),(14,14,8,2,3,2,5,9,5,3,8,37),(15,15,7,6,7,8,7,6,7,8,7,56),(16,16,8,7,3,7,5,6,6,7,7,49),(17,17,8,8,1,1,5,6,4,1,3,36),(18,18,7,5,8,6,8,7,7,4,1,46),(19,19,6,5,9,9,8,9,7,8,8,69),(20,20,7,5,7,8,8,8,8,8,9,65),(21,21,7,9,7,8,7,6,6,6,6,61),(22,22,9,5,6,7,8,6,7,9,8,65),(23,23,9,7,4,4,6,6,7,7,8,58),(24,24,3,8,5,5,8,6,6,6,8,55),(25,25,8,6,3,4,4,6,6,4,8,48),(26,26,7,5,9,9,0,0,0,0,7,37),(27,27,8,9,7,8,0,0,0,0,5,37),(28,28,7,5,9,9,0,0,0,0,6,36),(29,29,7,5,8,8,0,0,0,0,7,35),(30,30,8,7,3,6,0,0,0,0,7,31),(31,31,7,8,2,3,0,0,0,0,7,27),(32,32,7,7,3,7,0,0,0,0,4,28),(33,33,7,7,6,5,0,0,0,0,3,28),(34,34,5,2,9,9,0,0,0,0,2,27),(35,35,6,3,3,5,0,0,0,0,10,27),(36,36,3,8,9,8,0,0,0,0,7,35),(37,37,7,7,7,6,0,0,0,0,7,34),(38,38,8,6,7,5,0,0,0,0,8,34),(39,39,9,9,4,6,0,0,0,0,5,33),(40,40,8,5,9,9,0,0,0,0,1,32),(41,41,9,6,8,6,0,0,0,0,2,31),(42,42,8,7,2,3,0,0,0,0,8,28),(43,43,7,4,7,7,0,0,0,0,2,27),(44,44,7,3,5,3,0,0,0,0,2,20),(45,45,6,5,1,1,0,0,0,0,1,14),(46,46,6,5,8,9,0,0,0,0,9,37),(47,47,7,5,9,9,0,0,0,0,7,37),(48,48,9,9,3,5,0,0,0,0,10,36),(49,49,9,8,4,5,0,0,0,0,10,36),(50,50,7,4,7,8,0,0,0,0,9,35),(51,51,9,8,6,4,0,0,0,0,8,35),(52,52,8,7,7,5,0,0,0,0,8,35),(53,53,7,8,4,5,0,0,0,0,8,32),(54,54,8,9,2,2,0,0,0,0,9,30),(55,55,9,7,2,1,0,0,0,0,9,28),(56,56,7,5,9,9,0,0,0,0,5,35),(57,57,8,6,6,6,0,0,0,0,8,34),(58,58,9,5,6,4,0,0,0,0,9,33),(59,59,7,3,7,8,0,0,0,0,7,32),(60,60,8,6,6,7,0,0,0,0,5,32),(61,61,8,3,7,6,0,0,0,0,6,30),(62,62,6,5,8,9,0,0,0,0,1,29),(63,63,8,8,5,3,0,0,0,0,4,28),(64,64,8,8,2,2,0,0,0,0,1,21),(65,65,8,4,1,1,0,0,0,0,3,17),(66,66,6,6,8,8,0,0,0,0,9,37),(67,67,6,5,8,9,0,0,0,0,7,35),(68,68,6,5,7,7,0,0,0,0,9,34),(69,69,8,8,5,3,0,0,0,0,9,33),(70,70,8,9,4,2,0,0,0,0,9,32),(71,71,6,5,5,6,0,0,0,0,9,31),(72,72,7,5,6,5,0,0,0,0,7,30),(73,73,7,6,4,4,0,0,0,0,9,30),(74,74,4,5,5,7,0,0,0,0,8,29),(75,75,8,8,2,1,0,0,0,0,7,26),(76,76,9,5,1,1,0,0,0,0,1,17),(77,77,7,8,6,8,0,0,0,0,1,36),(78,78,6,3,9,9,0,0,0,0,7,34),(79,79,7,6,7,7,0,0,0,0,7,34),(80,80,6,4,7,7,0,0,0,0,7,31),(81,81,7,6,6,6,0,0,0,0,6,31),(82,82,9,3,4,4,0,0,0,0,7,27),(83,83,9,5,1,1,0,0,0,0,1,17),(84,84,7,4,2,2,0,0,0,0,1,16),(85,85,6,2,9,9,0,0,0,0,1,27),(86,86,9,8,4,5,0,0,0,0,6,32),(87,87,7,7,7,4,0,0,0,0,4,29),(88,88,9,3,8,8,0,0,0,0,1,29),(89,89,7,3,7,8,0,0,0,0,4,29),(90,90,6,2,9,9,0,0,0,0,1,27),(91,91,5,9,4,7,0,0,0,0,1,26),(92,92,7,8,4,6,0,0,0,0,1,26),(93,93,9,7,2,2,0,0,0,0,1,21),(94,94,6,5,4,3,0,0,0,0,1,19),(95,95,9,6,1,1,0,0,0,0,1,18),(96,96,9,8,6,8,0,0,0,0,5,36),(97,97,6,3,9,9,0,0,0,0,7,34),(98,98,7,6,7,7,0,0,0,0,7,34),(99,99,6,4,7,7,0,0,0,0,7,31),(100,100,7,6,6,6,0,0,0,0,6,31),(101,101,9,3,4,4,0,0,0,0,7,27),(102,102,7,4,5,5,0,0,0,0,5,26),(103,103,8,8,3,3,0,0,0,0,7,29),(104,104,9,5,1,1,0,0,0,0,1,17),(105,105,7,4,2,2,0,0,0,0,1,16);
/*!40000 ALTER TABLE `product_score` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2026-01-16 11:50:26
-- MySQL dump 10.13  Distrib 8.0.34, for macos13 (x86_64)
--
-- Host: 127.0.0.1    Database: aidb
-- ------------------------------------------------------
-- Server version	8.0.44

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!50503 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `user`
--

DROP TABLE IF EXISTS `user`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `user` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `provider` enum('naver','kakao','google') NOT NULL,
  `provider_uid` varchar(128) NOT NULL,
  `nickname` varchar(50) DEFAULT NULL,
  `email` varchar(100) DEFAULT NULL,
  `phone` varchar(20) DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_provider_uid` (`provider`,`provider_uid`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `user`
--

LOCK TABLES `user` WRITE;
/*!40000 ALTER TABLE `user` DISABLE KEYS */;
INSERT INTO `user` VALUES (2,'naver','rlO7UPg9oejq3YUvU4czEXRKxsYiJTopQ6f49xWTsWw','동키파파','dlawjdgur04@naver.com',NULL,'2026-01-09 14:43:46');
/*!40000 ALTER TABLE `user` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2026-01-16 11:50:26
-- MySQL dump 10.13  Distrib 8.0.34, for macos13 (x86_64)
--
-- Host: 127.0.0.1    Database: aidb
-- ------------------------------------------------------
-- Server version	8.0.44

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!50503 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `user_refresh_token`
--

DROP TABLE IF EXISTS `user_refresh_token`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `user_refresh_token` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `user_id` bigint unsigned NOT NULL,
  `refresh_token` varchar(255) NOT NULL,
  `expires_at` timestamp NOT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_refresh_token` (`refresh_token`),
  KEY `idx_user` (`user_id`),
  CONSTRAINT `fk_refresh_user` FOREIGN KEY (`user_id`) REFERENCES `user` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=35 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `user_refresh_token`
--

LOCK TABLES `user_refresh_token` WRITE;
/*!40000 ALTER TABLE `user_refresh_token` DISABLE KEYS */;
INSERT INTO `user_refresh_token` VALUES (3,2,'2d7648ed-f196-4333-b79c-863b9da19eef','2026-02-08 14:43:46','2026-01-09 14:43:46'),(4,2,'59137dc9-e8fa-408e-96b2-90bed93e6ee7','2026-02-08 15:12:39','2026-01-09 15:12:39'),(5,2,'f831789d-39bb-46fa-b039-78bb33d302b2','2026-02-08 15:13:02','2026-01-09 15:13:02'),(6,2,'5f56ae5a-8940-4102-b5c0-66f96d21ee4a','2026-02-08 15:15:32','2026-01-09 15:15:32'),(7,2,'b8b6ebbb-cda0-4323-a4bf-d84c61a137e8','2026-02-08 15:20:22','2026-01-09 15:20:22'),(8,2,'346e62f8-d7d2-43c6-a0bd-02865163faa6','2026-02-08 15:31:28','2026-01-09 15:31:28'),(9,2,'9e70eb0a-ed8e-429f-8984-a86e4c9edc6e','2026-02-08 15:31:47','2026-01-09 15:31:47'),(10,2,'4db26d55-4ebe-4039-95c6-f6a6cadf23dc','2026-02-08 15:32:19','2026-01-09 15:32:19'),(11,2,'4f72bc2f-d3c0-445c-b271-ecb2e62816d2','2026-02-08 15:37:30','2026-01-09 15:37:30'),(12,2,'5c2bd744-9648-486c-99d4-d3395b0f8853','2026-02-08 15:43:45','2026-01-09 15:43:45'),(13,2,'f49d6939-541d-4ab5-a84e-e40d4f9a1f35','2026-02-08 15:48:50','2026-01-09 15:48:50'),(14,2,'24c098d9-cf7b-488e-86a2-06bd6a360a35','2026-02-08 15:55:20','2026-01-09 15:55:20'),(15,2,'31a2e830-234b-408f-ba36-32cb62226223','2026-02-08 16:12:26','2026-01-09 16:12:26'),(16,2,'f20afb69-5fdf-443c-bf56-2ffbebd57628','2026-02-08 16:22:51','2026-01-09 16:22:51'),(17,2,'c63b5566-1606-47ef-b87c-0105cc0a32ec','2026-02-11 09:02:56','2026-01-12 09:02:56'),(18,2,'d5451eae-31be-43d0-9ad7-e34dc88d3312','2026-02-11 10:35:02','2026-01-12 10:35:02'),(19,2,'c800761a-d2dd-40a1-93e6-6eff23aa0173','2026-02-11 14:45:56','2026-01-12 14:45:56'),(20,2,'1838dcf9-70fe-4bab-be00-956b5e06ade3','2026-02-11 14:49:19','2026-01-12 14:49:19'),(21,2,'b7bc6fab-7280-4d47-b85f-dd5bd9597e9c','2026-02-11 15:32:52','2026-01-12 15:32:52'),(22,2,'04eb307b-4d6a-432b-bb14-a4f1fba0a37b','2026-02-11 15:53:09','2026-01-12 15:53:09'),(23,2,'5ccc5be6-80e6-4fcb-80d7-1326771946e9','2026-02-11 15:59:20','2026-01-12 15:59:20'),(24,2,'cbc2b9ef-a8e0-4488-948d-f36a847a60d7','2026-02-11 16:13:38','2026-01-12 16:13:38'),(25,2,'d2b8a314-4069-4e84-af20-5744c0ad126f','2026-02-12 09:26:06','2026-01-13 09:26:06'),(26,2,'6862e8fb-edf3-4e4d-ae3a-242921786e90','2026-02-12 10:28:23','2026-01-13 10:28:23'),(27,2,'a998a79d-e001-4226-b939-b65b7dc77ac0','2026-02-12 11:34:52','2026-01-13 11:34:52'),(28,2,'65761726-45c3-4978-8f0d-90f8c730875e','2026-02-12 12:39:13','2026-01-13 12:39:13'),(29,2,'d6ff5be3-f209-4c56-8be6-a20abd0ae7e0','2026-02-12 13:39:43','2026-01-13 13:39:43'),(30,2,'10aaf1ae-54bb-41a3-8fb6-eb841bc184a9','2026-02-12 17:37:35','2026-01-13 17:37:35'),(31,2,'3dbbb87b-f55d-4f76-a8d5-3ed74e79af4f','2026-02-14 14:26:34','2026-01-15 14:26:34'),(32,2,'493b3f01-027e-40aa-8ab2-a323fb64650a','2026-02-14 15:27:02','2026-01-15 15:27:02'),(33,2,'ee389e33-f34c-4c3a-9d25-191fbfc1c634','2026-02-14 16:27:26','2026-01-15 16:27:26'),(34,2,'f174108b-c8c1-4b25-b0be-f26affbc0da3','2026-02-15 09:34:47','2026-01-16 09:34:47');
/*!40000 ALTER TABLE `user_refresh_token` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2026-01-16 11:50:26
