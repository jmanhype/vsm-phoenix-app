#!/usr/bin/env python3
"""
VSM Phoenix Document Organizer
Analyzes and reorganizes the docs directory into a professional structure.
"""

import os
import re
import json
import shutil
from pathlib import Path
from datetime import datetime
from collections import defaultdict, Counter
import hashlib

# Configure for VSM Phoenix
INPUT_DIR = "./docs"  # Current docs directory
OUTPUT_DIR = "./docs_organized"  # Temporary output for review
ANALYSIS_DIR = "./docs_analysis"  # Analysis reports

class DocumentAnalyzer:
    def __init__(self, input_dir, output_dir, analysis_dir):
        self.input_dir = Path(input_dir)
        self.output_dir = Path(output_dir)
        self.analysis_dir = Path(analysis_dir)
        self.documents = []
        self.patterns = defaultdict(list)
        self.content_map = {}
        
    def setup_directories(self):
        """Create necessary output directories"""
        self.output_dir.mkdir(exist_ok=True)
        self.analysis_dir.mkdir(exist_ok=True)
        
        # Professional structure for VSM Phoenix
        dirs = [
            "01_overview",
            "02_architecture/vsm_systems",
            "02_architecture/mcp_integration", 
            "02_architecture/hive_mind",
            "03_api_reference/endpoints",
            "03_api_reference/schemas",
            "04_development/setup",
            "04_development/testing",
            "04_development/deployment",
            "05_user_guides/getting_started",
            "05_user_guides/tutorials",
            "06_references/external_docs",
            "06_references/specifications",
            "07_project_docs/planning",
            "07_project_docs/decisions",
            "08_archive/legacy",
            "08_archive/superseded"
        ]
        
        for dir_path in dirs:
            (self.output_dir / dir_path).mkdir(parents=True, exist_ok=True)
    
    def scan_documents(self):
        """Scan all markdown files and collect metadata"""
        print("Scanning VSM Phoenix documentation...")
        
        for file_path in self.input_dir.rglob("*.md"):
            # Skip README files in subdirectories for now
            if file_path.parent != self.input_dir and file_path.name == "README.md":
                continue
                
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
                
            doc_info = {
                'path': file_path,
                'name': file_path.name,
                'size': len(content),
                'content': content,
                'headers': self.extract_headers(content),
                'links': self.extract_links(content),
                'code_blocks': self.count_code_blocks(content),
                'lists': self.count_lists(content),
                'keywords': self.extract_keywords(content),
                'category': self.categorize_vsm_document(content, file_path),
                'hash': hashlib.md5(content.encode()).hexdigest(),
                'quality_score': self.assess_quality(content, file_path.name)
            }
            
            self.documents.append(doc_info)
        
        print(f"Found {len(self.documents)} documents")
    
    def extract_headers(self, content):
        """Extract all headers from markdown content"""
        headers = re.findall(r'^(#{1,6})\s+(.+)$', content, re.MULTILINE)
        return [(len(level), title.strip()) for level, title in headers]
    
    def extract_links(self, content):
        """Extract all links from markdown content"""
        links = re.findall(r'\[([^\]]+)\]\(([^)]+)\)', content)
        ref_links = re.findall(r'\[([^\]]+)\]:\s*(.+)$', content, re.MULTILINE)
        return links + ref_links
    
    def count_code_blocks(self, content):
        """Count code blocks and identify languages"""
        code_blocks = re.findall(r'```(\w*)\n(.*?)\n```', content, re.DOTALL)
        languages = Counter(lang for lang, _ in code_blocks if lang)
        return {'total': len(code_blocks), 'languages': dict(languages)}
    
    def count_lists(self, content):
        """Count different types of lists"""
        bullet_lists = len(re.findall(r'^\s*[-*+]\s+', content, re.MULTILINE))
        numbered_lists = len(re.findall(r'^\s*\d+\.\s+', content, re.MULTILINE))
        return {'bullet': bullet_lists, 'numbered': numbered_lists}
    
    def extract_keywords(self, content):
        """Extract VSM-specific keywords"""
        # Remove code blocks and links
        content_clean = re.sub(r'```.*?```', '', content, flags=re.DOTALL)
        content_clean = re.sub(r'\[([^\]]+)\]\([^)]+\)', r'\1', content_clean)
        
        # VSM-specific keywords to look for
        vsm_keywords = [
            'vsm', 'phoenix', 'mcp', 'hive', 'system1', 'system2', 'system3',
            'system4', 'system5', 'variety', 'cybernetic', 'genserver', 'elixir',
            'api', 'test', 'integration', 'architecture', 'goldrush', 'telemetry'
        ]
        
        keywords = []
        content_lower = content_clean.lower()
        for keyword in vsm_keywords:
            if keyword in content_lower:
                count = content_lower.count(keyword)
                keywords.append((keyword, count))
        
        return [k[0] for k in sorted(keywords, key=lambda x: x[1], reverse=True)][:10]
    
    def categorize_vsm_document(self, content, file_path):
        """Categorize document based on VSM project structure"""
        filename_lower = file_path.name.lower()
        content_lower = content.lower()
        path_str = str(file_path).lower()
        
        # Check subdirectory first
        if '/api' in path_str or 'api_documentation' in filename_lower:
            return 'api_reference'
        elif '/mcp' in path_str or 'mcp' in filename_lower:
            return 'mcp_integration'
        elif '/testing' in path_str or 'test' in filename_lower:
            return 'testing'
        elif '/archive' in path_str:
            return 'archive'
        
        # Filename patterns
        if 'hive' in filename_lower and 'architecture' in filename_lower:
            return 'hive_architecture'
        elif 'architecture' in filename_lower or 'design' in filename_lower:
            return 'architecture'
        elif 'cleanup' in filename_lower or 'plan' in filename_lower:
            return 'planning'
        elif 'test' in filename_lower or 'result' in filename_lower:
            return 'testing'
        elif 'proof' in filename_lower or 'validation' in filename_lower:
            return 'archive'  # These seem like temporary validation docs
        elif 'final' in filename_lower or 'complete' in filename_lower:
            return 'archive'  # Likely superseded docs
        
        # Content-based
        if 'endpoint' in content_lower or 'http' in content_lower:
            return 'api_reference'
        elif 'test' in content_lower and ('pass' in content_lower or 'fail' in content_lower):
            return 'testing'
        elif 'system 1' in content_lower or 'system1' in content_lower:
            return 'vsm_systems'
        
        return 'general'
    
    def assess_quality(self, content, filename):
        """Assess document quality"""
        score = 100
        
        # Deduct for problematic patterns
        if 'TODO' in content or 'FIXME' in content:
            score -= 10
        if re.search(r'shit|fuck|damn', content.lower()):
            score -= 20  # Unprofessional language
        if len(content) < 500:
            score -= 15  # Too short
        if not re.search(r'^#\s+', content, re.MULTILINE):
            score -= 10  # No proper header
        if filename.isupper() or '_' in filename:
            score -= 5  # Poor naming convention
        
        return max(0, score)
    
    def find_duplicates(self):
        """Find duplicate or near-duplicate content"""
        print("\nFinding duplicates...")
        duplicates = defaultdict(list)
        
        for i, doc1 in enumerate(self.documents):
            for doc2 in self.documents[i+1:]:
                if doc1['hash'] == doc2['hash']:
                    duplicates[doc1['hash']].append(doc1['path'])
                    duplicates[doc1['hash']].append(doc2['path'])
                elif self.similarity_ratio(doc1['content'], doc2['content']) > 0.85:
                    key = f"similar_{doc1['name']}_{doc2['name']}"
                    duplicates[key].extend([doc1['path'], doc2['path']])
        
        # Remove duplicate paths
        for key in duplicates:
            duplicates[key] = list(set(duplicates[key]))
        
        return dict(duplicates)
    
    def similarity_ratio(self, text1, text2):
        """Calculate similarity ratio between two texts"""
        set1 = set(text1.split())
        set2 = set(text2.split())
        intersection = set1.intersection(set2)
        union = set1.union(set2)
        return len(intersection) / len(union) if union else 0
    
    def analyze_patterns(self):
        """Analyze patterns specific to VSM Phoenix docs"""
        print("\nAnalyzing VSM documentation patterns...")
        
        # Category distribution
        categories = Counter(doc['category'] for doc in self.documents)
        
        # Quality assessment
        quality_scores = {doc['name']: doc['quality_score'] for doc in self.documents}
        avg_quality = sum(quality_scores.values()) / len(quality_scores) if quality_scores else 0
        
        # Common keywords
        all_keywords = []
        for doc in self.documents:
            all_keywords.extend(doc['keywords'])
        keyword_freq = Counter(all_keywords)
        
        # Document issues
        issues = {
            'unprofessional_language': [],
            'too_short': [],
            'poor_naming': [],
            'no_headers': []
        }
        
        for doc in self.documents:
            if doc['quality_score'] < 80:
                if re.search(r'shit|fuck|damn', doc['content'].lower()):
                    issues['unprofessional_language'].append(doc['name'])
                if len(doc['content']) < 500:
                    issues['too_short'].append(doc['name'])
                if doc['name'].isupper() or doc['name'].count('_') > 3:
                    issues['poor_naming'].append(doc['name'])
                if not doc['headers']:
                    issues['no_headers'].append(doc['name'])
        
        self.patterns = {
            'categories': dict(categories),
            'average_quality': avg_quality,
            'quality_scores': quality_scores,
            'common_keywords': keyword_freq.most_common(20),
            'issues': issues
        }
    
    def generate_analysis_report(self):
        """Generate VSM-specific analysis report"""
        print("\nGenerating analysis report...")
        
        duplicates = self.find_duplicates()
        
        report = {
            'project': 'VSM Phoenix',
            'scan_date': datetime.now().isoformat(),
            'total_documents': len(self.documents),
            'patterns': self.patterns,
            'duplicates': duplicates,
            'recommendations': self.generate_recommendations(),
            'document_list': [
                {
                    'name': doc['name'],
                    'path': str(doc['path']),
                    'category': doc['category'],
                    'quality_score': doc['quality_score'],
                    'size': doc['size'],
                    'keywords': doc['keywords'][:5]
                }
                for doc in sorted(self.documents, key=lambda x: x['quality_score'])
            ]
        }
        
        # Save reports
        with open(self.analysis_dir / 'vsm_docs_analysis.json', 'w') as f:
            json.dump(report, f, indent=2)
        
        self.generate_markdown_report(report)
    
    def generate_recommendations(self):
        """Generate specific recommendations"""
        recommendations = []
        
        if self.patterns['average_quality'] < 85:
            recommendations.append("Improve overall documentation quality")
        
        if self.patterns['issues']['unprofessional_language']:
            recommendations.append("Clean up unprofessional language in documents")
        
        if self.patterns['issues']['poor_naming']:
            recommendations.append("Rename files to use lowercase with hyphens")
        
        if len(self.find_duplicates()) > 0:
            recommendations.append("Consolidate duplicate documentation")
        
        # Check for missing docs
        categories = self.patterns['categories']
        if categories.get('api_reference', 0) < 2:
            recommendations.append("Expand API reference documentation")
        if categories.get('vsm_systems', 0) < 5:
            recommendations.append("Document each VSM system (1-5) separately")
        
        return recommendations
    
    def generate_markdown_report(self, report):
        """Generate markdown report for VSM Phoenix docs"""
        summary = f"""# VSM Phoenix Documentation Analysis

Generated: {report['scan_date']}

## Overview
- **Total Documents**: {report['total_documents']}
- **Average Quality Score**: {report['patterns']['average_quality']:.1f}/100

## Document Categories
"""
        
        for category, count in sorted(report['patterns']['categories'].items()):
            summary += f"- **{category}**: {count} documents\n"
        
        summary += "\n## Quality Issues Found\n"
        for issue_type, files in report['patterns']['issues'].items():
            if files:
                summary += f"\n### {issue_type.replace('_', ' ').title()}\n"
                for file in files[:5]:  # Show max 5 examples
                    summary += f"- {file}\n"
                if len(files) > 5:
                    summary += f"- ... and {len(files) - 5} more\n"
        
        summary += "\n## Duplicate Content\n"
        if report['duplicates']:
            for dup_group, files in list(report['duplicates'].items())[:5]:
                summary += f"- {', '.join(str(f) for f in files)}\n"
        else:
            summary += "No duplicates found.\n"
        
        summary += "\n## Recommendations\n"
        for rec in report['recommendations']:
            summary += f"- {rec}\n"
        
        summary += "\n## Proposed New Structure\n"
        summary += """
```
docs/
├── 01_overview/
│   ├── readme.md              # Project overview
│   └── quick-start.md         # Getting started guide
├── 02_architecture/
│   ├── vsm_systems/          # VSM Systems 1-5 docs
│   ├── mcp_integration/      # MCP integration docs
│   └── hive_mind/            # Hive mind architecture
├── 03_api_reference/
│   ├── endpoints/            # API endpoint docs
│   └── schemas/              # Data schemas
├── 04_development/
│   ├── setup/                # Development setup
│   ├── testing/              # Testing guides
│   └── deployment/           # Deployment docs
├── 05_user_guides/
│   ├── getting_started/      # User tutorials
│   └── tutorials/            # Advanced guides
└── 08_archive/               # Old/superseded docs
```
"""
        
        with open(self.analysis_dir / 'vsm_docs_analysis.md', 'w') as f:
            f.write(summary)
    
    def reorganize_documents(self):
        """Reorganize VSM Phoenix documents"""
        print("\nReorganizing documents...")
        
        category_mapping = {
            'api_reference': '03_api_reference/endpoints',
            'testing': '04_development/testing',
            'architecture': '02_architecture/vsm_systems',
            'hive_architecture': '02_architecture/hive_mind',
            'mcp_integration': '02_architecture/mcp_integration',
            'planning': '07_project_docs/planning',
            'archive': '08_archive/legacy',
            'vsm_systems': '02_architecture/vsm_systems',
            'general': '01_overview'
        }
        
        rename_map = {}
        
        for doc in self.documents:
            category = doc['category']
            target_dir = self.output_dir / category_mapping.get(category, '08_archive/legacy')
            
            # Generate clean filename
            clean_name = self.generate_clean_filename(doc)
            target_path = target_dir / clean_name
            
            # Copy file
            shutil.copy2(doc['path'], target_path)
            
            # Track renaming
            if doc['name'] != clean_name:
                rename_map[doc['name']] = clean_name
            
            self.content_map[str(doc['path'])] = str(target_path)
        
        # Save mappings
        with open(self.analysis_dir / 'content_map.json', 'w') as f:
            json.dump(self.content_map, f, indent=2)
            
        with open(self.analysis_dir / 'rename_map.json', 'w') as f:
            json.dump(rename_map, f, indent=2)
    
    def generate_clean_filename(self, doc):
        """Generate clean filename following conventions"""
        name = doc['name']
        
        # Special cases
        if 'README' in name:
            return 'readme.md'
        
        # Remove CAPS_WITH_UNDERSCORES pattern
        name = name.replace('.md', '')
        name = name.replace('_', '-')
        name = name.lower()
        
        # Clean up common patterns
        name = re.sub(r'-{2,}', '-', name)  # Multiple hyphens
        name = re.sub(r'^-|-$', '', name)   # Leading/trailing hyphens
        
        # Limit length
        if len(name) > 50:
            # Try to cut at word boundary
            name = name[:50].rsplit('-', 1)[0]
        
        return f"{name}.md"
    
    def run(self):
        """Run the complete analysis and reorganization"""
        print("Starting VSM Phoenix Documentation Analysis...")
        
        self.setup_directories()
        self.scan_documents()
        self.analyze_patterns()
        self.generate_analysis_report()
        self.reorganize_documents()
        
        print(f"\n✅ Analysis complete!")
        print(f"📊 Reports saved in: {self.analysis_dir}")
        print(f"📁 Proposed structure in: {self.output_dir}")
        print(f"\nReview the proposed structure before applying changes.")

def main():
    """Main execution"""
    analyzer = DocumentAnalyzer(INPUT_DIR, OUTPUT_DIR, ANALYSIS_DIR)
    analyzer.run()

if __name__ == "__main__":
    main()