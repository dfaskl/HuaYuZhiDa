package com.huayu.smartqa.repository;

import com.huayu.smartqa.model.DepartmentTag;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface DepartmentTagRepository extends JpaRepository<DepartmentTag, String> {
    Optional<DepartmentTag> findByTagId(String tagId);
    List<DepartmentTag> findByParentTag(String parentTag);
    boolean existsByTagId(String tagId);
} 