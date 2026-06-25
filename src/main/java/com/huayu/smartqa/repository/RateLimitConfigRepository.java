package com.huayu.smartqa.repository;

import com.huayu.smartqa.model.RateLimitConfig;
import org.springframework.data.jpa.repository.JpaRepository;

public interface RateLimitConfigRepository extends JpaRepository<RateLimitConfig, String> {
}
